# Capacity Management

!!! info "Required Role"
    **Administrator** or **Box Office** can manage production capacity. Only **Administrators** can create or delete seat maps.

**Navigation:** Theaters > [Theater Name] > [Production Name] > Edit

## Overview

Capacity in Stagemgr determines how many tickets can be sold for each performance of a production. The system uses a **hybrid capacity model** that automatically selects the right capacity source based on whether the production has a seat map assigned.

Understanding how capacity works is essential for preventing overselling, interpreting house counts, and managing inventory correctly.

## The Hybrid Capacity Model

Stagemgr determines a production's capacity using this logic:

| Condition | Capacity Source | Value |
|-----------|----------------|-------|
| Production **has** a seat map assigned | Seat map seat count | Number of actual seats in the map |
| Production **does not** have a seat map | Manual capacity field | Value entered on the production edit form |

This is implemented automatically -- there is no setting to toggle. The system always checks for a seat map first.

### Reserved Seating Productions

When a seat map is assigned to a production:

- **Capacity equals the number of seats** in the seat map
- Capacity updates **automatically** if seats are added to or removed from the map
- The manual capacity field on the production edit form is **ignored**
- This prevents overselling because you cannot sell more tickets than physical seats exist

!!! tip "Real-Time Accuracy"
    If you add or remove seats from a seat map (for example, adding wheelchair-accessible positions or removing damaged seats), the production capacity updates immediately. No manual adjustment is needed.

### General Admission Productions

When no seat map is assigned:

- **Capacity uses the manual value** entered on the production edit form
- You set this number when creating or editing the production
- It does not update automatically -- you must change it manually if the venue capacity changes

!!! warning "Keep Manual Capacity Current"
    For general admission productions, the manual capacity is your only safeguard against overselling. If your venue layout changes (tables added, chairs removed), update the capacity field to match.

## Where Capacity Is Used

The capacity value flows through many parts of Stagemgr:

### Availability Calculations

Each performance's available seats are calculated as:

**Seats available = Capacity - Tickets sold - Tickets held**

This number appears in the performance list, the public-facing purchase page, and the house count display.

### House Counts

The house count for each performance uses the production capacity as its **total seats** figure. House count metrics include:

| Metric | Calculation |
|--------|-------------|
| Total seats | Production capacity |
| Tickets sold | Count of processed ticket line items |
| Tickets held | Count of held orders |
| Seats remaining | Total seats - Sold - Held |
| Booking percentage | (Sold + Held) / Total seats |

### Sold-Out Detection

A performance is marked as **sold out** when seats remaining drops to zero or below. This:

- Removes the "Buy Tickets" button from the public website
- Shows "SOLD OUT" in the performance list
- Prevents new online orders (box office can still override with `sell_past_performances` permission)

### Dynamic Pricing Triggers

The **Shift When Capacity Over** trigger in [dynamic pricing](../productions/dynamic-pricing.md) uses the capacity-based sold percentage:

**Sold percentage = (Tickets sold / Capacity) x 100**

A larger capacity means each ticket sold represents a smaller percentage, so capacity shifts trigger later.

### Near-Capacity Warnings

When a performance approaches full capacity, the system surfaces warnings in the admin interface to alert staff that inventory is running low.

## Diagnosing Capacity Issues

### Unexpected Sold-Out Status

If a performance shows as sold out when it should not be:

1. **Check the production capacity** -- go to the production edit page and verify the capacity value
2. **Check for held orders** -- held orders consume capacity. Look for orders on HOLD that should be released or processed
3. **For reserved seating**, verify the seat map has the correct number of seats
4. **Recalculate house counts** -- occasionally house counts can fall out of sync. The system recalculates automatically via background jobs, but you can trigger a manual recalculation if needed

### Capacity Mismatch Between Seat Map and Expectation

If the capacity does not match what you expect for a reserved seating production:

1. Check the seat map in **Options > Venues > [Venue] > [Seat Map]**
2. Count the seats -- the capacity equals the total seat count in the map
3. Verify that all expected seats exist and none were accidentally deleted
4. Remember that wheelchair/accessible positions count as seats for capacity purposes

### Capacity Changed Unexpectedly

If the capacity value seems to have changed without your intervention:

- **Reserved seating**: Someone may have added or removed seats from the seat map. Check the seat map edit history.
- **General admission**: Check whether someone edited the production and changed the manual capacity field.

## Capacity and Ticket Class Allocations

Capacity is a production-level concept, but **ticket class allocations** control how that capacity is distributed across price tiers for each performance.

| Level | What It Controls |
|-------|-----------------|
| **Production capacity** | Total seats available per performance |
| **Ticket class allocation limits** | How many of those seats can be sold at each price tier |

The sum of all ticket class allocation limits can exceed the production capacity (overlapping allocations), but total sales across all classes cannot exceed the production capacity.

!!! note "Allocations vs. Capacity"
    Setting a ticket class allocation limit of 50 does not reserve 50 seats exclusively for that class. It means up to 50 tickets can be sold at that price. The overall capacity remains the hard ceiling regardless of individual allocation limits.

## Best Practices

1. **Use seat maps for reserved seating.** The automatic capacity from seat maps is more reliable than manual entry and eliminates the risk of capacity drift.

2. **Audit general admission capacity periodically.** Before each production, confirm the manual capacity matches your actual venue layout.

3. **Monitor house counts for anomalies.** If booking percentages look wrong, the first thing to check is whether the capacity value is correct.

4. **Consider held orders.** Held orders reduce available inventory. If availability seems lower than expected, check for held orders that may need to be released.
