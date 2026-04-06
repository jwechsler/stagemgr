# Advanced Dynamic Pricing Strategies

!!! info "Required Role"
    **Administrator** or **Box Office** can configure dynamic pricing. Read [Dynamic Pricing](../productions/dynamic-pricing.md) first for fundamentals.

**Navigation:** Productions > [Production Name] > Performances > [Performance] > Ticket Class Allocations

## Overview

The [Dynamic Pricing](../productions/dynamic-pricing.md) page covers the basics of shiftable ticket classes, triggers, and cascading. This page explores advanced strategies for combining triggers, designing multi-tier pricing structures, and handling common real-world scenarios.

## Combining Capacity and Time Triggers

Each shiftable allocation has two trigger fields: **Shift When Capacity Over** (percentage) and **Shift Days Before Performance** (days). These are evaluated with **OR logic** -- the shift activates when either condition is met.

This OR behavior enables several useful strategies:

### "Whichever Comes First" Pricing

Set both triggers to create a price increase that fires on whichever milestone is reached first:

| Code | Price | Shift To | Capacity Over | Days Before |
|------|-------|----------|---------------|-------------|
| `EARLY` | $20 | `REG` | 60% | 14 |
| `REG` | $35 | -- | -- | -- |

- If the show is selling well, price increases at 60% capacity (even if the show is months away)
- If sales are slow, price still increases 14 days before the performance (even if capacity is low)
- Patrons always see the right price relative to where the show is in its lifecycle

### "Safety Net" Pricing

Use a generous capacity trigger as the primary mechanism, with a tight time trigger as a safety net:

| Code | Price | Shift To | Capacity Over | Days Before |
|------|-------|----------|---------------|-------------|
| `T1` | $25 | `T2` | 50% | 3 |
| `T2` | $40 | -- | -- | -- |

The price increases at 50% sold, but even for a slow seller, it still increases 3 days before the show to capture last-minute demand at a higher price.

## Multi-Tier Cascading Strategies

Cascading shifts chain multiple price levels together. The system follows the chain until it reaches a non-shiftable class or a class whose triggers are not met.

### Four-Tier Progressive Pricing

For high-demand productions with long sales windows:

| Code | Name | Price | Shift To | Capacity Over | Days Before |
|------|------|-------|----------|---------------|-------------|
| `SUPER` | Super Early | $15 | `EARLY` | 30% | 30 |
| `EARLY` | Early Bird | $25 | `REG` | 55% | 14 |
| `REG` | Regular | $40 | `PREM` | 80% | 3 |
| `PREM` | Premium | $55 | -- | -- | -- |

**Behavior over time:**

1. On sale at $15 until 30% sold or 30 days before show
2. Shifts to $25 until 55% sold or 14 days before show
3. Shifts to $40 until 80% sold or 3 days before show
4. Final tier at $55

!!! tip "Cascade Limit"
    Stagemgr stops following cascading shifts after **15 iterations** to prevent infinite loops. In practice, you should never need more than 4--5 tiers.

### Asymmetric Cascading

Not all ticket classes need the same number of tiers. You can have different shift chains for different classes:

| Code | Name | Price | Shift To | Capacity Over | Days Before |
|------|------|-------|----------|---------------|-------------|
| `STU` | Student | $10 | `STU-REG` | 70% | 7 |
| `STU-REG` | Student Regular | $15 | -- | -- | -- |
| `GA` | General Admission | $25 | `GA-MID` | 50% | 14 |
| `GA-MID` | GA Mid-Tier | $35 | `GA-PREM` | 75% | 3 |
| `GA-PREM` | GA Premium | $45 | -- | -- | -- |

Students see a two-tier price structure while general admission has three tiers -- all driven by the same capacity and time triggers on the same performance.

## Common Patterns

### The "Early Bird" Pattern

The most common dynamic pricing setup. One shift from a discounted price to the standard price:

| Code | Price | Shift To | Capacity Over | Days Before |
|------|-------|----------|---------------|-------------|
| `EB` | $20 | `GA` | 50% | 14 |
| `GA` | $35 | -- | -- | -- |

Simple, easy to communicate to patrons, and effective at driving early purchases.

### The "Last-Minute Premium" Pattern

Keep a standard price for most of the sales window, then shift up close to showtime:

| Code | Price | Shift To | Capacity Over | Days Before |
|------|-------|----------|---------------|-------------|
| `GA` | $35 | `DOOR` | 90% | 1 |
| `DOOR` | $50 | -- | -- | -- |

Captures premium pricing from last-minute buyers without affecting early purchasers.

### The "Demand Surge" Pattern

Pure demand-based pricing with no time component. Set days before to `0` for all tiers:

| Code | Price | Shift To | Capacity Over | Days Before |
|------|-------|----------|---------------|-------------|
| `T1` | $20 | `T2` | 40% | 0 |
| `T2` | $30 | `T3` | 65% | 0 |
| `T3` | $45 | -- | -- | -- |

Price rises purely based on how fast the show is selling. A slow seller stays at $20 even on the day of the show.

!!! warning "Capacity Over = 0"
    Remember that `Shift When Capacity Over` set to `0` means the capacity trigger is **always active**. This is correct for time-only shifting, but if you want demand-only shifting, set `Days Before` to `0` instead (which means the time trigger is never active -- 0 days before means the day of the show).

## Strategy Selection Guide

| Goal | Recommended Pattern | Key Settings |
|------|---------------------|--------------|
| Reward early buyers | Early Bird | Low capacity threshold, 14--21 days before |
| Maximize last-minute revenue | Last-Minute Premium | High capacity threshold (85--95%), 1--2 days before |
| Pure demand-based pricing | Demand Surge | Progressive capacity thresholds, days before = 0 |
| Gradual price increase | Multi-Tier Cascade | 3--4 tiers with spaced capacity and time triggers |
| Different prices for different audiences | Asymmetric Cascade | Separate shift chains per ticket class |

## Interaction with Other Features

| Feature | Interaction |
|---------|------------|
| **Timed ticket classes** | Timed classes (using `minutes_before_show`) are evaluated independently. A timed class can also be shiftable. |
| **Web visibility** | If the shift-to target has `web_visible` unchecked, patrons cannot buy it online -- they must contact the box office. |
| **Special offers** | Special offers apply to the **resolved** ticket class (the final class after shifts), not the original. |
| **Comp tickets** | Comp classes can technically be shift targets, but this is rarely useful. |
| **Season seating** | Dynamic pricing works with season seating productions, but be cautious -- patrons may expect consistent pricing across the season. |

## Monitoring and Adjusting

After configuring dynamic pricing, monitor its effectiveness:

1. **Check the allocation table** on each performance to verify shift chains are correct
2. **Review sales reports** to see when shifts activated and how pricing affected revenue
3. **Compare performances** -- if one show shifts earlier than expected, adjust thresholds for remaining performances
4. **Adjust mid-run if needed** -- you can change shift thresholds on future performances without affecting past sales
