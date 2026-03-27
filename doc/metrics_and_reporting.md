# Metrics and Historical Reporting

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
| `sold_seats` | Tickets on Processed, Fulfilled, or Unclaimed orders |
| `held_seats` | Tickets on Hold-status orders |
| `available_seats` | Capacity minus all held seats (sold + held + other) |
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
