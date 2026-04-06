# General Admission vs. Reserved Seating

!!! info "Required Role"
    **Administrator** or **Box Office** can configure seating modes. Only **Administrators** can create or modify seat maps.

**Navigation:** Productions > [Production Name] > Edit

## Overview

Every production in Stagemgr operates in one of two seating modes: **general admission** or **reserved seating**. The mode is determined by whether a seat map is assigned to the production. This choice affects capacity management, the checkout flow, ticket printing, and box office operations.

## Choosing a Seating Mode

| Factor | General Admission | Reserved Seating |
|--------|------------------|-------------------|
| **Setup effort** | Minimal -- just set a capacity number | Requires a configured seat map for the venue |
| **Patron experience** | Patron selects ticket quantity only | Patron selects specific seats from an interactive map |
| **Capacity source** | Manually entered number | Automatically derived from seat count in the map |
| **Best for** | Standing-room, festival, cabaret, flexible layouts | Traditional theater with fixed rows and numbered seats |
| **Seat assignments** | Not applicable | Assigned during purchase or by box office |
| **Exchanges** | Simple quantity swap | Must release old seats and assign new ones |

## General Admission

General admission is the default mode. The production has a fixed capacity number that you set manually.

### How to Configure

1. Edit the production
2. Leave the **Seat Map** field blank (or set to "None")
3. Enter the maximum number of available seats in the **Capacity** field
4. Save the production

### How Capacity Works

- The capacity number represents the total seats available for every performance of this production.
- As tickets are sold, Stagemgr subtracts from this number to calculate remaining availability.
- The house count report shows total capacity vs. sold vs. remaining.
- Stagemgr prevents sales that would exceed capacity (overselling protection).

### Order Flow

1. Patron selects a performance date and time
2. Patron chooses ticket class and quantity
3. Patron completes payment
4. Tickets are issued without seat numbers

## Reserved Seating

Reserved seating assigns patrons to specific, numbered seats. It requires a seat map to be configured for the venue.

### How to Configure

1. Ensure the venue has at least one seat map configured (see venue administration)
2. Edit the production
3. Select the appropriate **Seat Map** from the dropdown -- only maps belonging to the production's venue are shown
4. The **Capacity** field automatically updates to reflect the number of seats in the map
5. Save the production

!!! warning "Changing Seat Maps After Sales"
    Avoid changing or removing a seat map after tickets have been sold. Existing seat assignments reference the current map. Changing it may orphan those assignments and cause errors in the box office view.

### How Capacity Works

- Capacity equals the number of seats defined in the seat map: `seat_map.seats.count`.
- If seats are added to or removed from the map, capacity updates automatically.
- You cannot manually override capacity when a seat map is assigned.
- Individual seats can be held or blocked, reducing available inventory without changing total capacity.

### Order Flow

1. Patron selects a performance date and time
2. Patron views the interactive seat map and selects specific seats
3. Selected seats are temporarily reserved during checkout
4. Upon payment, seat assignments are confirmed and locked
5. Tickets are issued with section, row, and seat numbers

### Seat Assignment Features

- **Holds:** Box office can place holds on specific seats, removing them from public sale while keeping them available for manual assignment.
- **Wheelchair accessibility:** Seats can be flagged as wheelchair-accessible in the seat map configuration. These seats appear with a distinct indicator on the map.
- **Manual assignment:** For ticket classes with `assigns_seats` enabled, box office staff can manually assign or reassign seats after purchase.

## Switching Between Modes

You can switch a production from general admission to reserved seating (or vice versa) by adding or removing a seat map assignment. However, this should only be done **before any tickets are sold**.

| Scenario | What Happens |
|----------|-------------|
| Adding a seat map | Capacity switches to seat count; existing performances retain their allocations |
| Removing a seat map | Capacity reverts to the manually entered value; any seat assignments become invalid |

!!! tip "Plan Ahead"
    Decide on your seating mode before creating performances and opening sales. While switching is technically possible, it can create data inconsistencies if orders already exist.

## Impact on Ticket Classes

Some ticket class settings behave differently depending on the seating mode:

| Setting | General Admission | Reserved Seating |
|---------|------------------|-------------------|
| **holds_seats** | Deducts from numeric capacity count | Blocks specific seats from sale |
| **assigns_seats** | No effect | Enables manual seat assignment by box office |
| **complimentary** | Separately inventoried against capacity | Comp seats can be assigned to specific locations |

## Impact on Reports

- **House Count:** Shows total capacity, sold, comped, held, and remaining for both modes. Reserved seating reports additionally show seat-level detail.
- **Box Office View:** General admission shows quantity-based inventory. Reserved seating shows the interactive map with color-coded seat status (available, sold, held, selected).

## Recommendations

- Use **general admission** for flexible or informal venues, outdoor events, festivals, standing-room shows, and any event where specific seat selection is unnecessary.
- Use **reserved seating** for traditional proscenium or thrust theaters with fixed, numbered seating where patrons expect to choose their seats.
- For venues that host both types, configure multiple seat maps (or use no map) and select the appropriate option per production.
