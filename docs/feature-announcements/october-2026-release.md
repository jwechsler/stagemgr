# Stagemgr Release Notes — October 2026

**For:** Box Office staff and Administrators

This release is mostly bug fixes. It also changes how refunds and exchanges work, so please read **What's New for Exchanges and Refunds** before your next shift.

---

## What's New for Exchanges and Refunds

### You can now refund an order that came from an exchange

**Before:** after a patron exchanged their tickets, the new order could not be refunded. If they then asked for their money back, the box office had to work around Stagemgr.

**Now:** open the **newest** order and click **Refund Order** as usual. Stagemgr follows the order back through every exchange to the patron's original payment and refunds it.

- The refund goes back the way the patron paid: to the original card, or as cash, check or flex pass/membership tickets. If they paid extra on a later exchange, that charge is refunded too.
- The refund page lists each order in the exchange history under its own heading, so you can see what will happen before you confirm.
- Only the newest order has a **Refund Order** button. The earlier orders show as **Exchanged** and stay that way.
- If any card refund fails, nothing is refunded and every order stays as it was. You can safely try again or refund another way.

### Exchange and Refund handles more cases

**Exchange and Refund** moves a patron to a cheaper performance or seat and gives the difference back.

- **Same price:** an exchange to tickets that cost the same as the originals used to be refused with a "Nothing to refund" error. Now the exchange goes through, and a blue information note confirms that no refund was needed.
- **The new tickets cost more:** the exchange is still refused, and the message now says how much more the new tickets cost. Use **Exchange Order** instead to charge the difference.
- **An order that was already exchanged:** if the order you're exchanging was itself paid with exchange credit, Stagemgr now finds the patron's original payment and refunds the difference to it. Before, this was refused with a message saying $0.00 could be refunded. The refund appears on the earlier order, next to the card it came from.

### Two people on the same order

If two staff members work on the same order at once, or a button is clicked twice, only the first action goes through. The second person sees a message explaining that the order has already been exchanged or refunded. Before, both could go through, which could leave an order refunded twice or exchanged and refunded at the same time.

### Refunds made directly in Stripe now show up in Stagemgr

Sometimes a refund has to be issued in the Stripe dashboard because something stopped it in Stagemgr. Until now that money never reached Stagemgr, so the box office totals didn't match what was actually collected.

**Now:**

- A refund made in Stripe is added to the matching order within moments, dated the day it was made, so it lands on that day's **Daily Receipts**. Its note reads *Refunded in Stripe dashboard*, followed by the reason picked in Stripe (for example *Requested by customer*).
- **Only the money changes.** Tickets, seats and the order's status are left alone, so the order may now be out of balance. For example, three $30 tickets with a $20 Stripe refund show $90 due but only $70 paid.
- The order is **flagged for review** so someone can tidy it up:
  - The order page shows a banner with the refund and how far the order is out of balance.
  - The **Orders** list shows a red **Review** label on the order, and **Needs review** in the Status filter lists every flagged order.
  - If the order had already been exchanged, the newest order in its exchange history is the one flagged, and its exchange credit is reduced by the refund, so a further exchange can't carry money that was already given back.
- From the banner, choose the fix that matches what happened. Each one asks for a short note:
  - **Keep tickets, apply as discount**: the patron keeps their tickets and the refund is treated as a discount.
  - **Mark fully refunded**: for a full Stripe refund; finishes the refund in Stagemgr and releases the seats without refunding the card a second time.
  - **Acknowledge**: leave the order as it is and record why.
  - **Exchange**: if the patron is giving up tickets, use the normal exchange.
- Refunds made in Stagemgr are never recorded twice.

!!! tip
    Refund in Stagemgr whenever you can. Use the Stripe dashboard only when Stagemgr can't do it, and then resolve the flag on the order.

---

## Bug Fixes

### Reserved seating

- **Change Seating left blank seats on tickets.** After moving a patron with **Change Seating**, their tickets could print without a seat number. The seat they gave up also couldn't be sold again, and selling it failed with an error. Both are fixed, and orders affected in the past have been repaired.
- **Refunded and unclaimed orders kept their seats.** Some refunded or unclaimed orders kept a hold on their seats, so those seats looked taken or failed to sell. Moving an order to another performance also left its old seats held. Seats are now always freed, and seats that were stuck have been released.
- **Pass redemptions and special offers lost their seat numbers.** Tickets redeemed with a flex pass or membership, or bought with a special offer, could print without a seat number. Their seat also showed the original ticket class, and saving the order in the admin screen undid the discounted class. Fixed, and upcoming orders affected by this have been repaired.
- **Bulk-imported subscriber seating** now creates one proper ticket per seat, so imported tickets print with their seats. A seat list with mistakes (repeated or empty seats) is refused with a clear message instead of being imported wrong. The season seating report now shows "2x SUB" instead of "1x SUB, 1x SUB".

### Refunds

- **Cash and check refunds after a partial refund** could give back the full original amount, even if part of it had already been refunded through **Exchange and Refund**. They now return only what's left. Some check refunds also failed with an error; those now go through.
- **Membership refunds made in Stripe** were recorded on the date of the original charge rather than the day of the refund, so they landed on the wrong day's Daily Receipts. A second partial refund on the same charge was also counted twice. Both are fixed.

---

## Questions?

The full instructions are in the user manual at stagemgr.theaterwit.org under **Ticketing → Refunds** and **Ticketing → Exchanges**. For anything else, contact the technical team.

*Released: October 2026*
