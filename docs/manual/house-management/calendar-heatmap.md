# Calendar Heatmap

!!! info "Role: Box Office Staff, House Managers, Administrators"
    The calendar heatmap is visible to all users on the public ticket purchase calendar. Configuration is managed by system administrators via `server.yml`.

---

## Overview

The calendar heatmap adds color-coded backgrounds to the ticket purchase calendar, giving patrons an at-a-glance view of how quickly performances are selling. Performances with strong sales are highlighted so buyers can see which dates still have good availability and which are filling up.

The heatmap uses pre-computed availability data from [house counts](house-counts.md), so it adds no extra load to the calendar page.

---

## How It Works

Each performance on the calendar is evaluated based on the **percentage of seats remaining** relative to the production's total capacity:

| Condition | Color | Meaning |
|-----------|-------|---------|
| More than 50% of seats available | White (no highlight) | Normal availability |
| 50% or fewer seats available | Light yellow | Popular performance -- selling well |
| 30% or fewer seats available | Light red | Near capacity -- limited availability |

The thresholds (50% and 30%) are configurable in `server.yml` (see [Configuration](#configuration) below).

---

## What the Calendar Looks Like

### Single performance per day

When a calendar date has one performance, the entire cell is shaded with the appropriate color.

### Multiple performances per day

When a calendar date has more than one performance at different availability levels:

- **Each performance** displays its own background color within the cell, so patrons can distinguish which showtime is selling faster.
- **The cell itself** displays a diagonal stripe pattern combining the colors present. For example, a day with one popular performance and one near-capacity performance would show yellow-and-red diagonal stripes behind the individual performance entries.

### Performances not highlighted

The following performances do not receive heatmap coloring:

- **Past performances** that are no longer on sale
- **Sold-out performances** (these already display "Sold out!")
- **Withheld performances** (blocked from public sale)

---

## Legend

When any performance on the current calendar month has a heatmap highlight, a legend appears in the calendar footer explaining the colors:

- A yellow swatch labeled **Popular performance**
- A red swatch labeled **Near capacity**

The legend only appears when relevant -- if all visible performances have normal availability, no legend is shown.

---

## Configuration

The heatmap thresholds are configured in `server.yml` under the `all:` section:

```yaml
all:
  calendar_display:
    warning_at: 50
    critical_at: 30
```

| Setting | Description | Default |
|---------|-------------|---------|
| `warning_at` | Percentage of seats remaining at or below which the yellow "popular" highlight appears | 50 |
| `critical_at` | Percentage of seats remaining at or below which the red "near capacity" highlight appears | 30 |

!!! tip "Choosing Thresholds"
    The right thresholds depend on your venue size and sales patterns. A 100-seat venue might use lower thresholds (e.g., 40/20) since each ticket represents a larger percentage of capacity. A 400-seat venue might keep the defaults or raise them (e.g., 60/40) to highlight popular shows earlier.

!!! note "Update Timing"
    Heatmap colors are based on [house count](house-counts.md) data, which is recalculated every 5 minutes. After a burst of sales, there may be a brief delay before the calendar colors update to reflect the new availability.

---

## Relationship to Other Features

| Feature | Relationship |
|---------|-------------|
| [House Counts](house-counts.md) | Heatmap reads pre-computed availability from house count records |
| [Capacity Management](../advanced/capacity-management.md) | The percentage calculation uses the production's capacity (seat map count or manual setting) |
| **Near-capacity restriction** (`restrict_sales_due_to_capacity_at` in `server.yml`) | A separate setting that transfers remaining inventory to the box office when a fixed number of seats remain. The heatmap's percentage-based thresholds are independent of this setting |
| [Dynamic Pricing](../productions/dynamic-pricing.md) | Both features respond to sales volume, but operate independently. Dynamic pricing shifts ticket classes; the heatmap is display-only |

---

## Troubleshooting

### Heatmap colors are not appearing

1. **Check `server.yml`** -- verify the `calendar_display` section exists under `all:` with `warning_at` and `critical_at` values.
2. **Check house counts** -- the heatmap requires house count records to exist. If a production was just created, wait up to 5 minutes for the `CalculateHouseCountsJob` to run.
3. **Check availability** -- if all performances have more than `warning_at`% seats remaining, no highlighting will appear (this is expected).

### Colors seem wrong or outdated

House counts update every 5 minutes. If a large batch of orders was just processed, the heatmap colors will catch up on the next calculation cycle.

### All performances show as highlighted

If your thresholds are set too high (e.g., `warning_at: 90`), most performances will be highlighted, reducing the usefulness of the feature. Consider lowering the thresholds so only genuinely popular performances stand out.
