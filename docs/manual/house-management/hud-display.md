# HUD Display

!!! info "Role: Administrators, Box Office Managers"
    The HUD (Heads-Up Display) system exports real-time sales and inventory data to text files for display on lobby monitors or office screens. These files provide at-a-glance visibility into ticket sales without requiring access to the Stagemgr admin interface.

**Navigation:** Configured in server settings; files are generated automatically by background jobs.

---

## What Is the HUD Display?

HUD stands for Heads-Up Display. Stagemgr generates fixed-width text files containing sales and inventory summaries formatted for monospace screens. These files are written on a schedule to a configurable output directory, where a display system (monitor, TV, dashboard application) can read and present them.

Typical uses include:

- **Box office lobby monitors** showing real-time seat availability.
- **Office dashboards** displaying daily and weekly sales performance.
- **Manager workstations** with a quick-reference sales ticker.

---

## Output Files

The HUD system generates four files, each serving a different reporting purpose:

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
| Sold | Tickets on paid orders (Processed, Fulfilled, or Unclaimed) |
| Held | Tickets on hold orders (reserved, not yet paid) |
| Remaining | Seats still available for sale |
| Max Price | Highest web-visible ticket price currently on sale |

**Update frequency:** Every 10 minutes.

---

### todays_counts.txt

Sales activity for the current day, grouped by production. Columns: `sold_on` (today's date), `name` (production, truncated to 24 chars), `orders` (distinct orders), `num_sold` (tickets sold), `Amount` (gross sales). Updated every 30 minutes.

```
+------------+--------------------------+--------+----------+--------+
| sold_on    | name                     | orders | num_sold | Amount |
+------------+--------------------------+--------+----------+--------+
| 2026-03-27 | The Ally                 |      6 |       12 | 374.00 |
| 2026-03-27 | Morning, Noon, and Night |      5 |        6 | 40.00  |
+------------+--------------------------+--------+----------+--------+
```

### last7_counts.txt

Aggregated sales for the last 7 days (yesterday through 7 days ago), grouped by production. Columns: `name`, `orders`, `num_sold`, `Amount` (with comma thousands separator). Updated daily at 1:15 AM.

```
+--------------------------+--------+----------+----------+
| name                     | orders | num_sold | Amount   |
+--------------------------+--------+----------+----------+
| Morning, Noon, and Night |     53 |       86 | 1,203.50 |
| The Ally                 |    148 |      297 | 4,803.80 |
+--------------------------+--------+----------+----------+
```

---

### previous7_counts.txt

Same format as `last7_counts.txt` but covers days 8 through 14 ago. Displayed alongside `last7_counts.txt`, this enables week-over-week sales trend comparison.

**Update frequency:** Daily at 1:20 AM.

---

## Update Schedule

| File | Frequency | Data Source |
|------|-----------|-------------|
| house_counts.txt | Every 10 minutes | HouseCount records (recalculated every 5 min) |
| todays_counts.txt | Every 30 minutes | RateOfSale intraday totals (updated every 30 min) |
| last7_counts.txt | Daily at 1:15 AM | RateOfSale records summed over 7 days |
| previous7_counts.txt | Daily at 1:20 AM | RateOfSale records for days 8-14 ago |

---

## File Format

All output files use a consistent fixed-width table format suitable for monospace displays:

| Format Rule | Detail |
|-------------|--------|
| Column borders | `+`, `-`, and `|` characters |
| String alignment | Left-aligned |
| Number alignment | Right-aligned |
| Currency values | 2 decimal places with comma thousands separators |
| Atomic writes | Files are written to a `.tmp` file first, then moved into place to prevent partial reads |

!!! tip
    The atomic write approach means display systems will never read a half-written file. You can safely poll these files on any interval without worrying about corrupt data.

!!! warning
    HUD files reflect the data as of their last generation time (shown in the "Generated" timestamp at the bottom of each file). During high-volume sales periods, there may be a lag of up to 10-30 minutes between a sale and its appearance in the HUD data.

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Files are empty | Verify that the calculation jobs have run; check that there are upcoming performances and recent sales data |
| Files are not updating | Check that the background job scheduler (Resque) is running and processing jobs |
| Stale timestamps | Review the "Generated" line at the bottom of each file; if it is hours old, the export job may have stopped |
| Output directory not found | Verify the `hud_export_directory` setting in server configuration |

---

## Related Pages

- [House Counts](house-counts.md) -- The underlying data that feeds house_counts.txt
- [Daily Operations](daily-operations.md) -- How HUD data fits into the day-of-show workflow
