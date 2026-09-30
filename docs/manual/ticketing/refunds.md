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
| **Payment type** | Any payment type that was reported as sales collected |

## Refund Process

### Step 1: Navigate to the Order

1. Find the order using the [Order Search](order-search.md)
2. Open the order detail page

### Step 2: Initiate the Refund

1. Click **Refund Order** in the action area
2. A confirmation dialog appears

### Step 3: Add Refund Notes (Optional)

The confirmation dialog may include a notes field where you can record:

- Reason for the refund
- Who authorized the refund
- Any relevant communication details

### Step 4: Confirm the Refund

1. Click **Confirm** to process the refund
2. The system performs the following actions automatically:

| Action | Description |
|--------|-------------|
| **Payment reversal** | Only payments marked as "report as sales collected" are reversed |
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
| **Comp** | No financial reversal needed |
| **Flex Pass** | Uses are restored to the flex pass |
| **Membership** | Membership usage is restored |

!!! warning "Credit Card Refunds"
    Credit card refunds are processed through Stripe and may take 5-10 business days to appear on the patron's statement. Inform the patron of the expected timeline.

!!! note "Processing Fees Are Not Reversed"
    When a credit card order is refunded, Stripe does not return the processing fee that was charged on the original transaction. The processing fee remains as a cost to the organization and will continue to appear on financial reports. This is standard credit card processor behavior.

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
| Refund button not available | Verify the order is in Processed or Fulfilled status |
| Credit card refund failed | Check Stripe dashboard for the transaction; the card may have expired or the account closed |
| Box office did not receive the refunded-order alert | Alerts are sent only for orders that were **Fulfilled** when refunded; check the order's history for the prior status and the configured box office and supervisor addresses |
| Need to reverse a refund | Not possible through the system; create a new order for the patron |
| Seats not released after refund | Verify the refund completed successfully; check for any system errors in the order history |
