# Dynamic Pricing

!!! info "Required Role"
    **Administrator** or **Box Office** can configure dynamic pricing through ticket class allocations.

**Navigation:** Productions > [Production Name] > Performances > [Performance] > Ticket Class Allocations

## Overview

Dynamic pricing in Stagemgr allows ticket classes to automatically shift sales from one price tier to another based on demand or timing. This is configured through the **shiftable** settings in each performance's ticket class allocation table. When a trigger condition is met, the system redirects new purchases from the original class to a different (typically higher-priced) class.

## How It Works

Dynamic pricing operates on a per-performance, per-ticket-class basis. Each allocation row can be marked as "shiftable" and given trigger conditions. When a patron attempts to purchase a shiftable ticket class and a trigger is active, the system automatically redirects the sale to the designated target class.

### The Three Configuration Fields

| Field | Description |
|-------|-------------|
| **Shiftable** | Checkbox. Must be checked to enable dynamic pricing for this allocation. |
| **Shift To Code** | The ticket class code that sales shift into when triggered. Select from the dropdown of available classes. |
| **Shift When Capacity Over** | A percentage (0--100). The shift activates when the performance's overall sold percentage exceeds this value. |
| **Shift Days Before Performance** | A number of days. The shift activates when the current date is within this many days of the performance date. |

### Trigger Logic

A shift activates when **either** trigger condition is met (they are evaluated with OR logic):

- **Capacity trigger:** `(tickets sold / total capacity) * 100 >= shift_when_capacity_over`
- **Time trigger:** `days until performance <= shift_days_before_performance`

When either condition is true, any new purchase attempt for the shiftable class is redirected to the `shift_to_code` class instead.

!!! tip "Using One Trigger"
    You do not need to set both triggers. Set capacity to `0` if you only want time-based shifting, or set days to `0` if you only want demand-based shifting.

## Cascading Shifts

The shift-to target class can itself be shiftable, creating a **cascade** of price tiers. Stagemgr follows the chain until it reaches a non-shiftable class or a class whose trigger conditions are not met.

To prevent infinite loops, the system stops after **15 iterations** of cascading shifts.

### Example: Three-Tier Cascade

Consider a 100-seat performance with these ticket classes and allocations:

| Code | Name | Price | Shiftable | Shift To | Capacity Over | Days Before |
|------|------|-------|-----------|----------|---------------|-------------|
| `EA` | Early Bird | $20 | Yes | `GA` | 50% | 14 |
| `GA` | General Admission | $35 | Yes | `PREM` | 80% | 3 |
| `PREM` | Premium | $50 | No | -- | -- | -- |

**How this plays out over time:**

1. **Weeks before the show, low sales (30% sold):** Patrons see and can buy `EA` at $20. Neither trigger is met.

2. **Sales cross 50% capacity (or 14 days before the show):** The `EA` allocation shifts to `GA`. Patrons who would have bought Early Bird now see General Admission at $35 instead. The Early Bird class effectively closes.

3. **Sales cross 80% capacity (or 3 days before the show):** The `GA` allocation shifts to `PREM`. Now General Admission redirects to Premium at $50. Since `PREM` is not shiftable, it remains the final price tier.

4. **Both triggers cascading:** If it is 3 days before the show AND capacity is at 85%, a patron attempting to buy `EA` follows the chain: EA shifts to GA (time trigger met), GA shifts to PREM (both triggers met). The patron is offered Premium at $50.

## Worked Example: Demand-Based Only

A 200-seat cabaret show wants prices to rise as seats sell:

| Code | Name | Price | Shiftable | Shift To | Capacity Over | Days Before |
|------|------|-------|-----------|----------|---------------|-------------|
| `T1` | Tier 1 | $15 | Yes | `T2` | 40% | 0 |
| `T2` | Tier 2 | $25 | Yes | `T3` | 70% | 0 |
| `T3` | Tier 3 | $35 | No | -- | -- | -- |

- 0--79 seats sold (under 40%): Tier 1 at $15
- 80--139 seats sold (40--69%): Tier 2 at $25
- 140+ seats sold (70%+): Tier 3 at $35

Days before is set to `0`, so only capacity percentage matters.

## Worked Example: Time-Based Only

A main stage show wants to increase prices as the performance approaches, regardless of sales volume:

| Code | Name | Price | Shiftable | Shift To | Capacity Over | Days Before |
|------|------|-------|-----------|----------|---------------|-------------|
| `ADV` | Advance | $30 | Yes | `REG` | 0 | 21 |
| `REG` | Regular | $40 | Yes | `DOOR` | 0 | 1 |
| `DOOR` | Door | $50 | No | -- | -- | -- |

- More than 21 days out: Advance at $30
- 21 days to 2 days out: Regular at $40
- Day of show: Door at $50

Capacity over is set to `0`, which means the capacity trigger is always met -- but in practice, the time trigger is the controlling factor since `0%` is always exceeded.

!!! warning "Capacity Over = 0"
    Setting `shift_when_capacity_over` to `0` means the capacity trigger is **always active** (any sales at all meet the condition). This is intentional when you want time-based-only shifting, but be aware it also means the shift activates as soon as the first ticket is sold if the time trigger is not constraining it.

## Configuration Tips

1. **Start simple.** A two-tier shift (early bird to regular) is easy to understand and communicate to patrons. Add tiers only when needed.

2. **Test with the allocation table.** After configuring shifts, verify the allocations on each performance to confirm the chain is correct.

3. **Consider the patron experience.** Patrons see the target class name and price, not the original. Make sure class names and purchase page annotations make sense to someone who never saw the lower tier.

4. **Monitor mid-run.** Check sales reports to see if your triggers are firing at the right points. Adjust thresholds for future performances if needed.

5. **Set ticket limits appropriately.** The ticket limit on a shiftable class does not affect when the shift triggers -- the trigger is based on overall performance capacity, not per-class sales. The limit only caps how many tickets of that specific class can be sold while it is active.

## Interaction with Other Features

- **Timed ticket classes** (Timed type with `minutes_before_show`) are evaluated independently of dynamic pricing shifts. A timed class can also be shiftable.
- **Web visibility** (`web_visible`) still applies. If the shift-to target class has `web_visible` unchecked, the patron cannot purchase it online -- they must contact the box office.
- **Complimentary classes** can be shift targets, though this is unusual.
