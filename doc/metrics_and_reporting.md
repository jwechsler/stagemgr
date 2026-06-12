# Metrics and Historical Reporting

## Seat inventory vocabulary

Seat-availability language is used in several places and is easy to confuse, so
the codebase now exposes a consistent set of self-describing names. The older
names still work (the new ones are aliases / thin delegators with no behavior
change); new code should prefer the clearer names.

Four distinct concepts:

| Concept | Meaning | Where |
|---------|---------|-------|
| **occupied** | Every seat currently spoken for: box-office holds, in-progress checkouts (New/Processing), settled sales (Processed/Fulfilled), plus seats mid-exchange/mid-release. The set of statuses is `Order::SEAT_OCCUPYING_STATUSES` (alias of `HOLDING_SEAT_STATUSES`). | `Performance#seats_occupied` (alias of `#seats_held`) |
| **on hold** | Only the box-office **Hold** status — seats a clerk parked for a patron who has not paid. Statuses: `Order::ON_HOLD_STATUSES` (alias of `HELD_STATUSES`). | `HouseCount#seats_on_hold` (reads `held_seats`) |
| **sold** | Tickets on settled orders (Processed, Fulfilled, Unclaimed) — the patron paid. | `HouseCount#seats_sold` (reads `sold_seats`) |
| **available** | Capacity minus all **occupied** seats. | `Performance#seats_available` (alias of `#number_of_seats_left`); `HouseCount#seats_available` (reads `available_seats`) |

Key point: **occupied is broader than on hold.** `held_seats` deliberately
counts only Hold-status orders ("heads on hold"), whereas `available_seats`
subtracts *all* occupying statuses. The two figures are intentionally different
and that difference is pinned by `spec/models/seat_inventory_vocabulary_spec.rb`.

### Live (Performance) vs cached (HouseCount)

- **`Performance`** computes occupied/available **live** from the orders table on
  every call — always current, slightly more expensive.
- **`HouseCount`** stores a **cached snapshot** of the same numbers. It is only
  refreshed when `CalculateHouseCountsJob` runs (every 5 minutes), so its values
  can briefly lag the live `Performance` figures.

After `house_count.calculate!`, the snapshot satisfies:

```ruby
house_count.available_seats == production.capacity - performance.seats_occupied
```

### Unrelated uses of the word "available"

Two other "available" concepts share the word but are *not* aggregate seat
counts — documented at their definitions:

- `SeatAssignment#available?` — per-seat reserved-seating status (is this
  individual seat unassigned / mine?).
- `TicketClassAllocation#available` — a boolean dynamic-pricing flag (is this
  ticket class currently offered for sale at this performance?).

## Overview

Stagemgr maintains two categories of historical show data that are calculated automatically by background jobs and stored in the database for reporting and display purposes.

## Rate of Sale (Daily Sales History)

The `RateOfSale` model stores a daily snapshot of ticket sales activity for each production. One record is created per production per day that had sales.

### Fields

| Field | Description |
|-------|-------------|
| `day_of_sale` | The date of the sales activity |
| `production` | The production these sales belong to |
| `total_single_tickets` | Paid ticket count (excludes comps) |
| `total_complimentary_tickets` | Complimentary ticket count |
| `gross_sales` | Total amount paid across all orders |
| `processing_fees` | Sum of processing and ticketing fees |
| `order_count` | Number of distinct orders placed |

### Calculation Schedule

- **Daily (00:30)**: `RateOfSalesJob` calculates the previous day's totals from settled TicketOrders (Processed, Fulfilled, Unclaimed).
- **Every 30 minutes**: The same job runs in intraday mode to keep today's record current as sales come in.

Records are upserted using `find_or_initialize_by(day_of_sale, production)`, so running the job multiple times for the same day safely updates the existing record.

### Backfill

To recalculate the last 30 days (e.g., after adding new fields or fixing a calculation):

```ruby
RateOfSalesJob.calculate_last_30_days
```

To calculate a specific date:

```ruby
RateOfSalesJob.calculate_for_day(Date.parse('2026-03-15'))
```

## House Count (Performance Inventory)

The `HouseCount` model tracks real-time seat inventory for each performance. One record exists per performance.

### Fields

| Field | Description |
|-------|-------------|
| `performance` | The performance this count tracks |
| `total_seats` | Production capacity (from seat map or manual setting) |
| `sold_seats` | Tickets on Processed, Fulfilled, or Unclaimed orders (read via `seats_sold`) |
| `held_seats` | Tickets on Hold-status orders only — "on hold" (read via `seats_on_hold`) |
| `available_seats` | Capacity minus all *occupied* seats — sold + on hold + in-progress + exchanging/releasing (read via `seats_available`) |
| `max_ticket_price` | Highest ticket price currently available to web buyers |

### Calculation Schedule

- **Every 5 minutes**: `CalculateHouseCountsJob` recalculates counts for any performance whose orders were recently updated, and for any production whose capacity changed.

### Key Details

- `sold_seats` counts tickets where the order is in a settled state (the patron paid).
- `held_seats` counts tickets where the order is in Hold status (reserved by box office, not yet paid).
- `available_seats` reflects the true remaining capacity after all seat-holding orders.
- `max_ticket_price` is the highest price among ticket classes that are available, web-visible, and marked for display in the pricing range. This can be `nil` if no eligible ticket classes exist.

### Backfill

To recalculate all house counts:

```ruby
CalculateHouseCountsJob.perform
```
