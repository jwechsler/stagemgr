# New Feature: Refund to Donation

## Overview

When a patron calls to donate tickets they cannot use, box office staff can now convert their ticket order directly into a donation — without issuing a refund and re-entering a separate donation. The payment moves to a new donation order, the seats are released for resale, and the patron receives credit for a tax-deductible donation.

## Who Can Use This

This action is available to **box office staff and administrators** only. It is not available to theater users.

## When Is It Available?

The "Refund to Donation" button appears on a ticket order when all of the following are true:

- The order is **Processed** or **Fulfilled**
- The order was paid with a **currency payment type** (cash, check, or credit card)
- The theater associated with the order is marked as a **501(c)(3)** (accepts donations)

It is **not** available for orders paid with a Flex Pass or Membership.

## How to Use

1. **Open the ticket order** in the admin panel (Admin → Ticket Orders → [find the order])

2. **Click "Refund to Donation"** — the button appears in the red action group alongside "Refund Order" and "Cancel Order"

3. **Confirm the action** when prompted — the dialog will ask you to confirm before proceeding

4. The system will automatically:
   - Release all reserved seats back to available inventory
   - Remove all ticket line items from the order
   - Create a new donation order in the patron's name for the full amount paid
   - Move the original payment to the new donation order
   - Mark the original ticket order as Canceled

5. You are redirected to the **new donation order**, which you can use to generate a donation receipt for the patron

## What Happens to the Data

| Item | Result |
|------|--------|
| Original ticket order | Marked **Canceled**, notes updated with reference to donation order |
| Seats | Released back to available |
| Ticket line items | Removed |
| Payment | Moved to the new donation order |
| New donation order | Created as **Processed**, same patron, same theater |
| Donation amount | Equal to the total amount originally paid |
| Donation receipt email | Sent automatically to the patron |

## Important Notes

- This action **cannot be undone** — if you need to reverse it, you will need to refund the donation order separately and re-enter the ticket order
- The donation order will be associated with the same patron address as the original ticket order
- The campaign field on the donation will be set to the production name
- A note is added to the canceled ticket order referencing the new donation order number, providing an audit trail

## Use Cases

- Patron calls to say they cannot attend and would like to donate their tickets
- Patron is unable to exchange into another performance and prefers to donate the value
- Group order where some tickets are being donated while others are exchanged (use Split Order first, then Refund to Donation on the relevant portion)

## Questions or Issues?

If you encounter any problems or have questions about using this feature, please contact the technical team or submit a support request through the admin dashboard.

---

*Feature added: March 2026*
