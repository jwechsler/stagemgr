# House Counts

!!! info "Role: House Managers, Box Office Staff, Administrators"
    House counts provide real-time tracking of seat inventory for every performance. They are the primary tool for understanding how many seats are sold, held, and available.

**Navigation:** Admin > House Management > Dashboard

---

## What House Counts Track

A house count record exists for each performance and tracks the following metrics:

| Metric | Description |
|--------|-------------|
| Total Seats | The full capacity of the venue for this production (from seat map or manual capacity setting) |
| Sold | Number of tickets on paid orders (Processed, Fulfilled, or Unclaimed status) |
| Held | Number of tickets on Hold orders (reserved but not yet paid) |
| Remaining | Seats still available for sale (Total Seats minus Sold minus Held) |
| Percentage Booked | The proportion of capacity that is sold or held, shown as a percentage |

!!! tip
    The "Remaining" count is the number you should reference when a patron asks if tickets are available. It accounts for both paid orders and held reservations.

---

## How House Counts Are Calculated

House counts are automatically recalculated by a background job (`CalculateHouseCountsJob`) that runs **every 5 minutes**. The calculation process:

1. Queries all ticket orders for the performance.
2. Counts tickets by order status (sold vs. held).
3. Subtracts sold and held from total capacity to determine remaining.
4. Updates the HouseCount record with the new values.

### Capacity Source

The total seats value comes from the production's capacity setting:

| Production Type | Capacity Source |
|----------------|-----------------|
| Reserved seating (with seat map) | Automatically uses the count of seats in the assigned seat map |
| General admission (no seat map) | Uses the manually configured capacity value on the production |

!!! warning
    If house counts appear incorrect, the most common cause is a recently changed seat map or capacity setting. The house count will update within 5 minutes when the next calculation job runs. For immediate recalculation, an administrator can trigger it manually.

---

## Dashboard View

The House Management dashboard displays house counts for upcoming performances in a summary table:

| Column | Description |
|--------|-------------|
| Performance | Production name and performance date/time |
| Sold | Number of paid tickets |
| Held | Number of held tickets |
| Remaining | Available seats |
| % Booked | Percentage of capacity sold or held |

Performances are listed in chronological order, with today's performances at the top.

---

## Per-Performance Breakdown

Clicking on a specific performance in the dashboard opens a detailed view showing:

- **Ticket class breakdown**: How many tickets are sold in each price tier (e.g., Regular, Student, Senior).
- **Order status breakdown**: Counts by order state (Hold, Processed, Fulfilled, Unclaimed).
- **Seat assignment status** (for reserved seating): Which specific seats are occupied, held, or available.

---

## Understanding the Numbers

| Scenario | Sold | Held | Remaining | Interpretation |
|----------|------|------|-----------|----------------|
| Early sales | 12 | 3 | 85 | Low demand so far; plenty of availability |
| Strong advance | 78 | 8 | 14 | Approaching capacity; consider limiting holds |
| Sold out | 95 | 5 | 0 | No seats available; held orders occupy remaining capacity |
| Oversold warning | 102 | 0 | -2 | More tickets sold than capacity; investigate immediately |

!!! warning
    A negative remaining count indicates an oversell situation. This can happen if capacity was reduced after tickets were sold (e.g., a seat map was modified). Contact an administrator to resolve the discrepancy.

---

## Snapshots and History

House count snapshots are saved periodically, creating a historical record of how inventory changed over time. This data is used for:

- **Rate of sale analysis**: Understanding how quickly tickets are selling.
- **Reporting**: Comparing advance sales across performances or productions.
- **Troubleshooting**: Investigating discrepancies by reviewing how counts changed.

---

## Automatic Updates and Refresh

| Component | Update Frequency |
|-----------|-----------------|
| HouseCount records | Every 5 minutes (CalculateHouseCountsJob) |
| HUD display files | Every 10 minutes (ExportHouseCountsJob) |
| Dashboard view | Refreshed on page load |

!!! tip
    If you need the absolute latest count during a fast-selling performance, refresh the House Management dashboard page. The displayed data reflects the most recent calculation job run.

---

## Related Pages

- [Daily Operations](daily-operations.md) -- Day-of-show workflow using house counts
- [Fulfilling Orders](fulfilling-orders.md) -- How fulfillment affects house counts
- [HUD Display](hud-display.md) -- Exporting house count data for lobby monitors
