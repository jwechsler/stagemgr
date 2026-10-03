# Refunds

!!! info "Role: Box Office Staff, Administrators"
    Refunds reverse payment on a ticket order and release all associated seats. This is a terminal operation that cannot be undone.

**Navigation:** Stagemgr > Orders > Ticket Orders > [Select Order] > Refund Order

## Overview

A refund cancels a ticket order by reversing the payment and releasing the seats back to available inventory. Once refunded, the order is permanently set to **Refunded** status and cannot be modified or restored.

## When to Use a Refund

- Patron requests a full refund for their tickets
- Performance is canceled and patrons are being refunded
- Order was created in error and needs to be reversed
- Patron cannot attend and does not wish to exchange or donate

!!! tip "Consider Alternatives"
    Before processing a refund, consider whether an [exchange](exchanges.md) or [refund to donation](refund-to-donation.md) might better serve both the patron and the organization.

## Refund Eligibility

The Refund Order button is available when:

| Condition | Requirement |
|-----------|-------------|
| **Order status** | Must be **Processed** or **Fulfilled** |
| **Exchanges** | Only the newest order of an exchange chain; orders it was exchanged from are **Exchanged** and show no button |

!!! note "Refunding an Exchanged Order"
    An order created by an exchange carries the earlier order's payment as exchange credit. Refunding it settles the whole chain of exchanges behind it (e.g. A exchanged for B, B for C -- refund C):

    - Each order in the chain is listed on the refund page under its own heading, with what happens to each of its payments.
    - The original card, cash, check or pass payment is refunded on its own tender, on whichever order holds it; a card charged for a pricier exchange is refunded too. A card already partly refunded by **Exchange and Refund** returns only what is left on it.
    - Exchange credits and offsets, and Carryover write-offs, are reversed, so every order in the chain nets to zero.
    - The newest order becomes **Refunded** and releases its seats; the earlier orders stay **Exchanged**.
    - If any card refund fails, nothing is refunded and every order is left as it was.

## Refund Process

### Step 1: Navigate to the Order

1. Find the order using the [Order Search](order-search.md)
2. Open the order detail page

### Step 2: Initiate the Refund

1. Click **Refund Order** in the action area
2. The refund page opens, showing the full order and, under *Refunding returns each payment on its own tender*, one line for each payment on the order saying what will happen to it

| Payment | What the Refund Page Says |
|---------|---------------------------|
| **Credit card** | The card and the amount that will be refunded to it |
| **Cash** | The amount to give the patron in cash |
| **Check / External** | The refund amount that will be recorded |
| **Membership** | The number of tickets released back to the membership |
| **Flex pass** | The number of tickets returned to the pass |

### Step 3: Add Refund Notes (Optional)

The refund page includes a **Notes** field where you can record:

- Reason for the refund
- Who authorized the refund
- Any relevant communication details

### Step 4: Confirm the Refund

1. Click the refund button -- **Process Refund** when money goes back, or **Cancel Membership reservation** / **Release Flex Pass tickets** when the order was paid only with a pass
2. The system performs the following actions automatically:

| Action | Description |
|--------|-------------|
| **Payment reversal** | Every payment that was collected and still has something to return is refunded on its own tender |
| **Seat release** | All reserved seats are released back to available inventory |
| **Status update** | Order status changes to **Refunded** |
| **Box office alert** | If the order was **Fulfilled**, an alert email goes to the box office and supervisor addresses (the patron is not emailed) |

### Step 5: Verify Completion

After the refund processes:

1. The order detail page shows the **Refunded** status
2. Payment records show the reversal
3. Seats appear as available on the seat map (for reserved seating)
4. House count is updated to reflect the released seats

## Payment Reversal Details

The refund method depends on the original payment type:

| Original Payment | Refund Method |
|-----------------|---------------|
| **Credit Card** | Refund issued to the original card via Stripe |
| **Cash** | Record indicates cash refund to be given at box office |
| **Check** | Record indicates check refund to be issued |
| **External** | Record indicates refund through original external method |
| **Flex Pass** | Uses are restored to the flex pass |
| **Membership** | Membership usage is restored |

### Orders With Several Payments

An order can carry more than one payment -- for example after [Add to Order](add-to-order.md), or a membership order with a card-paid extra seat. One refund handles them all: each payment goes back the way it came in, as listed on the refund page.

- A card payment that was already **partly refunded** (for example by **Exchange and Refund**) returns only what is left on that charge.
- If the order holds a payment kind the refund page cannot return (such as a *Carryover*), the page says *Can't refund this order* and names the payment kind, and no refund button is shown.

!!! warning "Credit Card Refunds"
    Credit card refunds are processed through Stripe and may take 5-10 business days to appear on the patron's statement. Inform the patron of the expected timeline.

!!! note "Processing Fees Are Not Reversed"
    When a credit card order is refunded, Stripe does not return the processing fee that was charged on the original transaction. The processing fee remains as a cost to the organization and will continue to appear on financial reports. This is standard credit card processor behavior.

## Refunds Made in Stripe

Sometimes a refund has to be issued straight from the Stripe dashboard -- for example when something stops a refund or exchange inside Stagemgr. Stagemgr hears about it from Stripe within moments and records the money, so box office totals stay right:

- Each Stripe refund becomes one refund payment on the order, for that refund's amount, dated the day it was made in Stripe (so it lands on that day's Daily Receipts). Its note reads *Refunded in Stripe dashboard*, followed by the reason picked in Stripe's refund dialog when there is one (for example *Refunded in Stripe dashboard: Requested by customer*).
- A ticket order's refund is recorded against the card it came from, so a later refund in Stagemgr returns only what is left on that card. A membership refund is recorded as a negative subscription payment.
- Refunds Stagemgr issues itself are never recorded twice, and neither is a refund Stripe reports more than once.
- A refund Stripe holds as *pending* (for example when the Stripe balance can't cover it yet) is recorded once Stripe reports it succeeded.
- **Only the money changes.** Tickets, seats and the order's status stay as they are. Instead the order is flagged for review.

!!! warning "A refund Stagemgr cannot match"
    If a Stripe refund matches no payment in Stagemgr, nothing is recorded and an error report is sent to the system administrator with the Stripe charge and refund ids.

### The Review Queue

A flagged order shows a red **Review** badge beside its status in the [orders listing](order-search.md); hover over it to see why (e.g. *Stripe refund $20.00 on 10/02*). To see every order waiting, choose **Needs review** in the status filter.

The order page shows a **Needs review** banner with the reason and the order's balance, for example:

> Stripe refund $20.00 on 10/02
>
> Order is $20.00 out of balance (due $90.00, paid $70.00).

For an order made by an exchange, the balance covers the orders it was exchanged from too. Membership orders show the reason only: their monthly payments never match their line items.

### Resolving a Review

!!! info "Role: Box Office Staff, Administrators"
    The same staff who can exchange an order.

Type an optional **Note** in the banner, then choose one fix. Each one records the note and who resolved the review in the order's change history, and clears the badge.

| Fix | What It Does | Offered When |
|-----|--------------|--------------|
| **Keep tickets, apply as discount** | The patron keeps the tickets. A *Stripe refund adjustment* line is added for the difference, so the order balances. | The order is underpaid |
| **Mark fully refunded** | Refunds the order as described above: seats are released and the order becomes **Refunded**. The card is not refunded again. | Every card on the order is already refunded in full in Stripe |
| **Remove tickets (exchange)** | Opens the [exchange](exchanges.md) page, to exchange the order for fewer tickets | The order can be exchanged |
| **Acknowledge** | Records the note and leaves the order as it is | Always |

If the order is refunded again in Stripe after a review is resolved, it is flagged again.

## Notification Behavior

Stagemgr does not email the patron about a refund. Tell the patron yourself, including the credit card timeline above.

When the refunded order was **Fulfilled**, its tickets have already been printed or handed over, so the system emails an internal alert asking staff to make sure those tickets are destroyed:

| Original Status | Alert Sent? |
|----------------|-------------|
| **Processed** | No |
| **Fulfilled** | Yes -- to the **Box Office** and **Supervisor Notifications** addresses |

The alert is titled "Warning: Fulfilled order *number* refunded" and names the staff member who processed the refund. It goes out within a few minutes, when the background task runner next checks for pending tasks. The recipients are the server-level addresses described in [Email Configuration](../setup/email-configuration.md).

## Important Rules

1. **Terminal operation** -- Refunded orders cannot be un-refunded, exchanged, or modified in any way
2. **Full refund only** -- The system refunds the entire order amount. Partial refunds are not supported through this workflow.
3. **Inventory impact** -- All seats and ticket allocations are released immediately
4. **Audit trail** -- The refund is recorded in the order history with timestamp and any notes entered
5. **Report impact** -- Refunded orders appear in financial reports as negative adjustments

!!! warning "Cannot Be Reversed"
    Once a refund is processed, there is no undo. If tickets need to be re-issued to the same patron, a brand new order must be created.

## Partial Refund Scenarios

Since the system only supports full-order refunds, partial refund scenarios require a workaround:

1. **Split first** -- Use [Split Orders](split-orders.md) to divide a multi-ticket order into two orders
2. **Refund one** -- Refund the order containing the tickets to be returned
3. **Keep the other** -- The remaining order stays in Processed/Fulfilled status

This approach preserves the tickets the patron wants to keep while refunding only the unwanted portion.

## Troubleshooting

| Issue | Resolution |
|-------|------------|
| Refund button not available | Verify the order is in Processed or Fulfilled status. An **Exchanged** order is refunded from the newest order of its exchange chain. |
| *Can't refund this order* on the refund page | The page lists why: the order is not Processed or Fulfilled, holds a payment kind the refund cannot return (ask an administrator), was exchanged for a later order (refund that one), or is part-way through an exchange (finish or abandon the exchange first) |
| Credit card refund failed | Check Stripe dashboard for the transaction; the card may have expired or the account closed |
| Refunded in the Stripe dashboard instead | The refund is recorded on the order automatically and the order is flagged; see [Refunds Made in Stripe](#refunds-made-in-stripe) |
| Box office did not receive the refunded-order alert | Alerts are sent only for orders that were **Fulfilled** when refunded; check the order's history for the prior status and the configured box office and supervisor addresses |
| Need to reverse a refund | Not possible through the system; create a new order for the patron |
| Seats not released after refund | Verify the refund completed successfully; check for any system errors in the order history |
