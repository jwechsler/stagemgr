# Split Orders

!!! info "Role: Box Office Staff, Administrators"
    Splitting an order divides a multi-ticket order into two separate orders, each with its own subset of tickets and seats. This is useful when part of a group needs different handling.

**Navigation:** Stagemgr > Orders > Ticket Orders > [Select Order] > Split Order

## Overview

The split order feature takes a single order containing multiple tickets and divides it into two new orders. The original order is marked as **Split** (a terminal state), and two new orders are created, each containing a portion of the original tickets.

## When Is Splitting Available?

The Split Order button appears when **all** of the following conditions are met:

| Condition | Requirement |
|-----------|-------------|
| **Number of tickets** | Order must contain **more than 1 ticket** |
| **Order status** | Must be **Processed**, **Unclaimed**, or **Fulfilled** |
| **Payment type** | Must **not** be paid with a Membership |

!!! warning "Single-Ticket Orders"
    An order with only one ticket cannot be split. There must be at least two tickets to divide.

## Split Process

### Step 1: Initiate the Split

1. Navigate to the ticket order you want to split
2. Click **Split Order**
3. The split interface appears, showing all tickets on the order

### Step 2: Assign Tickets to New Orders

The interface displays all ticket line items from the original order. You assign each ticket to one of the two new orders:

| Assignment | Description |
|------------|-------------|
| **Order A** | First new order -- receives the assigned tickets |
| **Order B** | Second new order -- receives the remaining tickets |

Each ticket must be assigned to exactly one of the two new orders. At least one ticket must be in each order.

### Step 3: Seat Redistribution (Reserved Seating)

For reserved seating orders, seats must be redistributed along with the tickets:

1. Each seat assignment from the original order is linked to a specific ticket
2. When tickets are assigned to the new orders, their seat assignments follow
3. Verify that the seat distribution makes sense (e.g., keeping adjacent seats together for groups)

### Step 4: Confirm the Split

1. Review the ticket and seat distribution between the two new orders
2. Confirm the split
3. The system creates the two new orders

## What Happens During a Split

| Item | Result |
|------|--------|
| **Original order** | Status changes to **Split** (terminal) |
| **New Order A** | Created with assigned tickets, same patron address, same payment proportionally allocated |
| **New Order B** | Created with remaining tickets, same patron address, same payment proportionally allocated |
| **Ticket line items** | Redistributed between the two new orders |
| **Seat assignments** | Moved to the corresponding new orders (reserved seating) |
| **Payment** | Distributed proportionally based on ticket values |
| **Order notes** | Original order notes are copied to both new orders |

## After the Split

Each new order is an independent order that can be managed separately:

- **Exchange** one order while keeping the other
- **Refund** one order while keeping the other
- **Refund to Donation** on one order
- **Fulfill** each order independently
- **Further split** either new order (if it has multiple tickets)

The original order remains in the system with **Split** status for audit purposes. It references both new orders.

## Common Use Cases

### Partial Refund

Since Stagemgr only supports full-order refunds, splitting enables partial refunds:

1. Split the order, placing the tickets to be refunded in one order
2. Refund that order
3. The other order retains the tickets the patron wants to keep

### Group Separation

A group purchased tickets together but some members need changes:

1. Split the order to separate the members who need changes
2. Exchange, refund, or modify the separated order as needed
3. The remaining group members' order is unaffected

### Partial Donation

Some tickets in an order should be donated while others are kept:

1. Split the order to separate the tickets being donated
2. Use [Refund to Donation](refund-to-donation.md) on the donation portion
3. The other order remains as-is

!!! tip "Plan Before Splitting"
    Decide exactly which tickets go to which order before starting the split. This avoids confusion and ensures the right tickets end up in the right order.

## Important Rules

1. **Terminal operation** -- The original order becomes **Split** and cannot be restored
2. **Two orders only** -- Each split creates exactly two new orders. To split into three, perform a second split on one of the new orders.
3. **Same patron** -- Both new orders are associated with the same patron address as the original
4. **Audit trail** -- The original order references both new orders, and each new order references the original
5. **Membership restriction** -- Orders paid with a membership cannot be split

## Troubleshooting

| Issue | Resolution |
|-------|------------|
| Split button not available | Verify the order has more than one ticket, is in an eligible status, and was not paid with a membership |
| Cannot assign seats correctly | Review the seat map to ensure each seat is assigned to the correct new order |
| Need to undo a split | Not possible; manage the two new orders individually instead |
| Payment distribution seems wrong | Payment is split proportionally by ticket value; verify the ticket class pricing |
