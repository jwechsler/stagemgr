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

## Revenue Vocabulary

Revenue figures span every payment method (credit cards, third-party, comps that
back gift certificates, etc.), so the canonical terms deliberately avoid the word
"cash" — cash is just one payment type. There are three core concepts:

| Term | Meaning |
|------|---------|
| `collected` | Total of all payments on the scoped orders (every payment type). Human-facing label: **"Revenue Collected"**. |
| `reportable` | The sales-reportable subset of `collected` — only payments whose payment type has `report_as_sales_collected?`. Excludes things like membership/flex-pass redemptions that are gross but not collected as sales. |
| `net` | `reportable` minus ticketing (facility) and processing fees. The house's take-home figure. |

### Single source of truth: `RevenueCalculator`

`RevenueCalculator` (`app/services/revenue_calculator.rb`) is the one place that
computes these figures for an arbitrary scope of orders. Its `Result` struct
exposes `collected`, `reportable`, `ticketing_fees`, `processing_fees`, `net`,
and ticket/order counts. (`cash_collected` / `cash_reportable` remain as
deprecated aliases for backward compatibility; new code should use
`collected` / `reportable`.)

Callers that route through `RevenueCalculator`:

- **`RateOfSalesJob`** — daily `gross_sales` is `RevenueCalculator#collected`.
- **`TicketRevenueAnalysis`** — its dynamic-pricing summary pulls `collected`.
- **`SalesByPerformanceReport`** — its per-performance columns are
  `revenue_collected` (= `collected`, labeled "Revenue Collected"),
  `reportable` (= `reportable`), the fee columns, and `net`.
- **`RoyaltyReport`** — pulls the processing-fee total from `RevenueCalculator`.
  Note: royalty **gross** stays on the `royalty_gross` basis (royalty contracts
  value the show on face/royalty price, not collected revenue), and **ticketing
  fees are intentionally excluded** from royalty net pending business review, so
  royalty net = `royalty_gross` minus processing fees only.

### Deliberately order-local

`OrderReport#order_revenue` is **not** routed through `RevenueCalculator`. It is a
single order's `total_paid` minus that order's fees, and must reflect every
payment on the order regardless of payment type or order status — whereas
`RevenueCalculator#net` is built on the reportable subset and only counts settled
orders. The math is therefore kept inline and order-scoped.

## Rate of Sale (Daily Sales History)

The `RateOfSale` model stores a daily snapshot of ticket sales activity for each production. One record is created per production per day that had sales.

### Fields

| Field | Description |
|-------|-------------|
| `day_of_sale` | The date of the sales activity |
| `production` | The production these sales belong to |
| `total_single_tickets` | Paid ticket count (excludes comps) |
| `total_complimentary_tickets` | Complimentary ticket count |
| `gross_sales` | Total amount paid across all orders (`RevenueCalculator#collected` — includes third-party/external payments and ticketing fees) |
| `processing_fees` | **Legacy combined figure**: sum of ticketing + processing fees. Kept as-is for backward compatibility; prefer `ticketing_fees` (below) when you need the ticketing portion alone. |
| `ticketing_fees` | Isolated ticketing (facility) fee for the day (`RevenueCalculator#ticketing_fees`). **Nullable** — `nil` means the row predates this column and has not yet been backfilled (see Backfill). |
| `order_count` | Number of distinct orders placed |

### Analysis revenue basis

`RateOfSalesAnalysis` does **not** report raw `gross_sales`. Its revenue series
(weekly totals, daily rolling, momentum, ratio, projections, and insights) all
use **analysis revenue = `gross_sales − (ticketing_fees || 0)`**: all payments
(including third-party) net of ticketing fees but gross of processing fees —
the same treatment as `RoyaltyReport`. Rows with `nil` `ticketing_fees` fall
back to `gross_sales`, so the figure is slightly overstated for un-backfilled
rows; run the backfill task below for historical comparability.

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

#### Backfilling `ticketing_fees`

The `ticketing_fees` column was added after the table already had history. Rows
created before it default to `nil` and fall back to `gross_sales` in the
analysis. **This task must be run in production** so historical comparisons in
`RateOfSalesAnalysis` are on the correct net-of-ticketing-fees basis:

```bash
bundle exec rake rate_of_sales:backfill_ticketing_fees
```

It recomputes **only** the `ticketing_fees` column (via the same
`RevenueCalculator` path the daily job uses) and leaves all other columns
untouched. It is idempotent; by default it only fills rows where
`ticketing_fees IS NULL`. Pass `FORCE=1` to recompute every row (e.g. after a
`RevenueCalculator` change).

## Rate of Sales Analysis & Revenue Projection

`RateOfSalesAnalysis` (`app/services/rate_of_sales_analysis.rb`) compares a
target production's sales trajectory against a set of historical comparison
productions and projects remaining revenue. Key conventions:

- **Week buckets** anchor on `presale_cutoff = first_playing_date − 21 days`.
  Bucket *N* spans `[presale_cutoff + (N−1)·7, presale_cutoff + N·7)`. Because
  runs are short (4–7 weeks) and opening-aligned, "Week 4" is opening week for
  every show, so week labels are directly comparable across productions.
- **Partial final week**: actuals are cut at the start-of-week `cutoff`, which
  rarely lands on a bucket boundary, so the newest actual bucket is usually
  partial. Its revenue still counts in the cumulative actual totals (real
  money), but it is **excluded** from the performance ratio and the momentum
  window so results don't depend on which weekday the report runs. Its
  unplayed days are projected as the first projected increment (expected week
  value × ratio, pro-rated by `remaining_days / 7`).
- **Pre-sales** are never part of the expectation curve, ratio, or momentum —
  presale periods vary too much between productions.
- **Expectation curve (historical-scaled projection)**: built from **matching
  weeks** — expected revenue for target Week *N* is the comparison average at
  "Week *N*". The comparisons' decline tail is **end-aligned** to the target's
  closing week (closing-week dynamics belong at the close). If the target runs
  longer than the comparisons, the gap between the last matching body week and
  the end-aligned tail is filled with the plateau level (average of the last
  two body weeks). The result is multiplied by the weighted performance ratio
  and capped by remaining seat inventory × average realized ticket price.
  `extra_weeks` widens the plateau gap.
- **Self-scaled (momentum) projection**: anchors on the target's recent 7-day
  rolling revenue and applies a weekly rate derived from the daily-rolling
  trajectory (last 7 complete days vs the prior 7), clamped to ±`MOMENTUM_CLAMP_PCT`%
  and **decayed by half each successive projected week** (`MOMENTUM_DECAY`) so
  momentum fades toward flat rather than compounding over a short run. Both
  constants are exposed at the top of the class and are intended to be tunable.

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
