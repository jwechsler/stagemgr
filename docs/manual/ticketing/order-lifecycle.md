# Order Lifecycle

!!! info "Role: All Staff"
    Understanding order statuses is essential for all box office staff, managers, and administrators. Every order in Stagemgr follows a defined lifecycle from creation through completion.

**Navigation:** Stagemgr > Orders > [Any Order Type]

## Overview

Every order in Stagemgr has a **status** that indicates where it is in its lifecycle. The system defines 12 possible statuses, and orders move between them through staff actions, customer activity, and automated processes.

## Order Statuses

| Status | Description |
|--------|-------------|
| **Hold** | Seats are reserved but no payment has been collected. The order is a placeholder awaiting conversion to a sale. |
| **New** | The order has just been created and is awaiting initial processing. This is a brief transitory state. |
| **Processing** | The order is actively being processed (e.g., payment authorization in progress). This is a brief transitory state. |
| **Processed** | Payment has been collected and the order is confirmed. Tickets are ready for pickup or delivery. |
| **Fulfilled** | The patron has received their tickets (picked up at will-call, printed, or delivered). |
| **Unclaimed** | The performance has passed and the patron never picked up or used their tickets. |
| **Exchanging** | The order is in the middle of an exchange operation. The original order holds this status while the new order is being created. |
| **Releasing** | The order is in the process of having its seats released back to inventory. |
| **Refunded** | The order has been fully refunded. Payment has been reversed and seats released. This is a terminal state. |
| **Exchanged** | The order was exchanged for a new order. The original order retains this status permanently. This is a terminal state. |
| **Canceled** | The order has been canceled. This is a terminal state. |
| **Split** | The order was split into two new orders. The original order retains this status permanently. This is a terminal state. |

## Status Groups

Stagemgr groups statuses into logical sets used throughout the system for filtering, reporting, and determining available actions.

| Group | Statuses | Purpose |
|-------|----------|---------|
| **Held** | Hold | Orders reserving seats without payment |
| **Holding Seat** | Hold, New, Processing, Processed, Exchanging, Releasing, Fulfilled | All orders that are currently occupying a seat in inventory |
| **Transitory** | New, Processing | Brief intermediate states during order creation |
| **Unprocessed** | Hold, New, Processing | Orders that have not yet completed payment |
| **Attending** | Processed, Fulfilled | Confirmed patrons expected to attend |
| **Settled** | Processed, Fulfilled, Unclaimed, Refunded, Exchanged | Orders that have reached a stable state |
| **Finalized** | Processed, Fulfilled, Unclaimed | Completed orders with collected revenue |

## State Diagram

```
                    +-------+
                    | Hold  |
                    +---+---+
                        |
                        v
  (New Order) ---> +-------+     +------------+
                   |  New  | --> | Processing |
                   +-------+     +-----+------+
                                       |
                                       v
                                 +-----------+
                          +----->| Processed |<-----+
                          |      +-----+-----+      |
                          |            |             |
                          |     +------+------+      |
                          |     |      |      |      |
                          |     v      v      v      |
                     +---------+ +----+---+ +-+--------+
                     |Fulfilled| |Exchange| |  Refund  |
                     +---------+ +----+---+ +----------+
                          |           |
                          v           v
                    +-----------+ +----------+
                    | Unclaimed | | Exchanged|
                    +-----------+ +----------+
```

## Common Workflows

### New Sale (Standard)
1. Staff creates order and enters payment
2. Order passes through **New** and **Processing** automatically
3. Order arrives at **Processed**
4. Staff fulfills the order at will-call --> **Fulfilled**
5. If unclaimed after the performance --> **Unclaimed**

### Hold, Then Process
1. Staff creates a hold order --> **Hold**
2. Patron confirms and provides payment
3. Staff processes the hold --> **Processed**
4. Normal fulfillment follows

### Exchange
1. Staff initiates exchange on a Processed or Fulfilled order
2. Original order --> **Exchanging**
3. New order is created with new performance/seats
4. Original order --> **Exchanged** (terminal)
5. New order --> **Processed**

### Refund
1. Staff initiates refund on a Processed or Fulfilled order
2. Payment is reversed
3. Order --> **Refunded** (terminal)

### Split
1. Staff splits a multi-ticket order
2. Original order --> **Split** (terminal)
3. Two new orders are created as **Processed**

## Available Actions by Status

| Status | Available Actions |
|--------|-------------------|
| **Hold** | Process (convert to sale), Cancel |
| **New** | None (transitory -- resolves automatically) |
| **Processing** | None (transitory -- resolves automatically) |
| **Processed** | Fulfill, Exchange, Refund, Cancel, Split, Refund to Donation |
| **Fulfilled** | Exchange, Refund, Split, Refund to Donation |
| **Unclaimed** | None (terminal for most purposes) |
| **Exchanging** | None (resolves when exchange completes) |
| **Releasing** | None (resolves automatically) |
| **Refunded** | None (terminal) |
| **Exchanged** | None (terminal) |
| **Canceled** | None (terminal) |
| **Split** | None (terminal) |

!!! warning "Terminal States"
    Orders in **Refunded**, **Exchanged**, **Canceled**, or **Split** status cannot be modified further. If a mistake was made, a new order must be created manually.

!!! tip "Quick Reference"
    The most common statuses you will work with day-to-day are **Hold**, **Processed**, and **Fulfilled**. The transitory states (New, Processing) pass by automatically and rarely require attention.
