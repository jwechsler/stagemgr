# HUD Display Output

## Overview

Stagemgr can generate fixed-width text files for display on HUD (heads-up display) monitors. These files contain sales and inventory summaries formatted for monospace screens. They are written on a schedule to a configurable output directory.

## Configuration

Set the output directory in `config/server.yml`:

```yaml
all:
  hud_export_directory: "/tmp"
```

This can be overridden per environment:

```yaml
production:
  hud_export_directory: "/var/www/hud"
```

The directory must exist and be writable by the Rails process. All four output files are written to this location.

## Output Files

### house_counts.txt

Real-time seat inventory for upcoming performances (next 14 days).

```
HOUSE COUNTS
+------------+------+------+-----------+-----------+
| Code       | Sold | Held | Remaining | Max Price |
+------------+------+------+-----------+-----------+
| ALLY0327   |   54 |   33 |        13 |     24.00 |
| NOON0327   |   25 |   18 |        61 |     60.00 |
+------------+------+------+-----------+-----------+
Generated Fri Mar 27 13:26:57 CDT 2026
```

| Column | Description |
|--------|-------------|
| Code | Performance code (e.g., ALLY0327 = The Ally, March 27) |
| Sold | Tickets on paid orders (Processed/Fulfilled/Unclaimed) |
| Held | Tickets on Hold orders (reserved, not yet paid) |
| Remaining | Seats still available for sale |
| Max Price | Highest web-visible ticket price currently on sale |

**Schedule**: Updated every 10 minutes by `ExportHouseCountsJob`.
Data source: `HouseCount` records (recalculated every 5 minutes).

### todays_counts.txt

Sales activity for the current day, grouped by production.

```
+------------+--------------------------+--------+----------+--------+
| sold_on    | name                     | orders | num_sold | Amount |
+------------+--------------------------+--------+----------+--------+
| 2026-03-27 | The Ally                 |      6 |       12 | 374.00 |
| 2026-03-27 | Morning, Noon, and Night |      5 |        6 | 40.00  |
+------------+--------------------------+--------+----------+--------+
Generated Fri Mar 27 13:30:01 CDT 2026
```

| Column | Description |
|--------|-------------|
| sold_on | Today's date |
| name | Production name (truncated to 24 characters) |
| orders | Number of distinct orders placed |
| num_sold | Total tickets sold (paid + complimentary) |
| Amount | Gross sales amount |

**Schedule**: Updated every 30 minutes by `ExportTodaysCountsJob`.
Data source: `RateOfSale` record for today (recalculated every 30 minutes).

### last7_counts.txt

Aggregated sales for the last 7 days (yesterday through 7 days ago), grouped by production.

```
+--------------------------+--------+----------+----------+
| name                     | orders | num_sold | Amount   |
+--------------------------+--------+----------+----------+
| Morning, Noon, and Night |     53 |       86 | 1,203.50 |
| The Ally                 |    148 |      297 | 4,803.80 |
+--------------------------+--------+----------+----------+
```

| Column | Description |
|--------|-------------|
| name | Production name (truncated to 24 characters) |
| orders | Total orders across the 7-day period |
| num_sold | Total tickets sold |
| Amount | Gross sales amount (with comma thousands separator) |

**Schedule**: Generated daily at 1:15 AM by `ExportSalesCountsJob`.
Data source: `RateOfSale` records summed over the date range.

### previous7_counts.txt

Same format as `last7_counts.txt` but covers days 8 through 14 ago. Useful for comparing week-over-week sales trends.

**Schedule**: Generated daily at 1:20 AM by `ExportSalesCountsJob`.

## Schedule Summary

| File | Job | Frequency |
|------|-----|-----------|
| house_counts.txt | ExportHouseCountsJob | Every 10 minutes |
| todays_counts.txt | ExportTodaysCountsJob | Every 30 minutes |
| last7_counts.txt | ExportSalesCountsJob (last7) | Daily at 1:15 AM |
| previous7_counts.txt | ExportSalesCountsJob (previous7) | Daily at 1:20 AM |

Supporting calculation jobs that feed these exports:

| Job | Frequency | Purpose |
|-----|-----------|---------|
| CalculateHouseCountsJob | Every 5 minutes | Recalculates HouseCount records |
| RateOfSalesJob | Daily at 00:30 | Calculates yesterday's sales totals |
| RateOfSalesJob (intraday) | Every 30 minutes | Updates today's sales totals |

## File Format

All output files use MySQL `--table=true` style formatting:
- Column borders use `+`, `-`, and `|` characters
- Strings are left-aligned, numbers are right-aligned
- Currency values show 2 decimal places with comma thousands separators
- Files are written atomically (to a `.tmp` file first, then moved into place) to prevent partial reads by display systems

## Troubleshooting

To manually regenerate any file from the Rails console:

```ruby
ExportHouseCountsJob.perform
ExportTodaysCountsJob.perform
ExportSalesCountsJob.perform('last7')
ExportSalesCountsJob.perform('previous7')
```

If files are empty, verify that the calculation jobs have run:

```ruby
# Check for recent RateOfSale data
RateOfSale.where(day_of_sale: 7.days.ago..Date.current).count

# Check for HouseCount data
HouseCount.joins(performance: :production).where(performances: { performance_date: Date.today..(Date.today + 14.days) }).count
```
