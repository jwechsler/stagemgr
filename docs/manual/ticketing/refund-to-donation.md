# Refund to Donation

!!! info "Role: Box Office Staff, Administrators"
    This feature converts a ticket order directly into a donation, releasing the seats for resale and giving the patron credit for a tax-deductible contribution. It is not available to theater-level users.

**Navigation:** Stagemgr > Orders > Ticket Orders > [Select Order] > Refund to Donation

## Overview

When a patron calls to donate tickets they cannot use, box office staff can convert their ticket order directly into a donation -- without issuing a refund and re-entering a separate donation. The payment moves to a new donation order, the seats are released for resale, and the patron receives credit for a tax-deductible donation.

## When Is It Available?

The "Refund to Donation" button appears on a ticket order when **all** of the following conditions are met:

| Condition | Requirement |
|-----------|-------------|
| **Order status** | **Processed** or **Fulfilled** |
| **Payment type** | Currency payment (cash, check, or credit card) |
| **Theater status** | Theater is marked as a **501(c)(3)** organization |

!!! warning "Not Available For"
    This action is not available for orders paid with a Flex Pass or Membership, because those payment types cannot be converted to a charitable donation.

## How to Use

1. **Open the ticket order** -- Navigate to the order via Admin > Ticket Orders or use [Order Search](order-search.md)

2. **Click "Refund to Donation"** -- The button appears in the red action group alongside "Refund Order" and "Cancel Order"

3. **Confirm the action** when prompted -- The dialog asks you to confirm before proceeding

4. The system automatically performs the following:
    - Releases all reserved seats back to available inventory
    - Removes all ticket line items from the order
    - Creates a new donation order in the patron's name for the full amount paid
    - Moves the original payment to the new donation order
    - Marks the original ticket order as **Canceled**

5. You are redirected to the **new donation order**, which you can use to generate a donation receipt for the patron

## What Happens to the Data

| Item | Result |
|------|--------|
| Original ticket order | Marked **Canceled**, notes updated with reference to donation order |
| Seats | Released back to available inventory |
| Ticket line items | Removed from the original order |
| Payment | Moved to the new donation order |
| New donation order | Created as **Processed**, same patron, same theater |
| Donation amount | Equal to the total amount originally paid |
| Campaign | Set to the production name |
| Donation receipt email | Sent automatically to the patron |

## Important Rules

- This action **cannot be undone** -- if you need to reverse it, you must refund the donation order separately and re-enter the ticket order
- The donation order is associated with the same patron address as the original ticket order
- The campaign field on the donation is set to the production name automatically
- A note is added to the canceled ticket order referencing the new donation order number, providing a complete audit trail

!!! warning "Irreversible Action"
    Once confirmed, the conversion cannot be undone through a single action. Reversing it requires refunding the donation order and manually creating a new ticket order.

## Common Use Cases

### Patron Cannot Attend
A patron calls to say they cannot make the performance and would like to donate the value of their tickets rather than receive a refund.

### Exchange Not Possible
A patron cannot find a suitable alternative performance for an exchange and prefers to convert the ticket value into a tax-deductible donation.

### Partial Group Donation
A group order where some tickets are being donated while others are exchanged. Use [Split Orders](split-orders.md) first to separate the tickets, then apply Refund to Donation on the relevant portion.

## Comparison with Standard Refund

| Feature | Refund | Refund to Donation |
|---------|--------|--------------------|
| Payment returned to patron | Yes | No (becomes donation) |
| Seats released | Yes | Yes |
| Original order status | Refunded | Canceled |
| New order created | No | Yes (donation order) |
| Tax-deductible for patron | No | Yes |
| Receipt sent | Refund notification (if fulfilled) | Donation receipt |
| Available payment types | All | Currency only (cash, check, credit card) |
| Requires 501(c)(3) theater | No | Yes |

!!! tip "Patron Communication"
    When discussing this option with a patron, emphasize that the full ticket value becomes a tax-deductible donation. This is often more attractive than a simple refund, especially for patrons who want to support the theater.

## Troubleshooting

| Issue | Resolution |
|-------|------------|
| Button not visible | Verify all three conditions: order is Processed/Fulfilled, paid with currency, and theater is 501(c)(3) |
| Paid with flex pass or membership | This feature is not available for non-currency payments. Use a standard refund instead. |
| Need to reverse the conversion | Refund the donation order, then create a new ticket order manually |
| Donation receipt not sent | Verify the patron's email address on the order |
