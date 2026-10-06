# Stagemgr Release Notes — Prepaid Gift Memberships

**For:** Box Office staff, Development staff and Administrators

You can now sell a membership that is paid once, up front, and runs for a fixed term: a prepaid one-year gift membership, for example. Gift subscriptions also now stop billing when the gift is over, and a long-standing problem with gift dates has been fixed.

---

## What's New

### Prepaid (one-time) memberships

**Before:** every membership was a subscription that charged the patron again each month or year. A membership offer set up with a one-time price in Stripe could not be bought: checkout failed with *"There was a problem setting up your account for the … payment plan."*

**Now:** give a membership offer a **one-time** price in Stripe and it becomes a prepaid membership:

- The patron's card is charged **once**, for the full price. Nothing renews and the card is never charged again.
- The membership is a normal membership in every other way: a member number, an ID card, member pricing, and the email list.
- It runs for the offer's **Gift duration** in months (12 if left blank). It starts on the day of purchase or, for a gift, on the **Keep secret until...** date if that is later.
- On the gift purchase page the buyer sees *"This gift membership lasts 12 months and does not renew."* The confirmation email gives the date the membership runs through.

### The Expires date

Every prepaid membership has an **Expires** date: the **last day** it can be used. A 12-month membership that starts October 6, 2026 expires October 5, 2027.

- It appears as **Expires** on the membership's page, and in the **Membership End** column of the Memberships list with a blue **Expires** label.
- To extend or shorten a membership, change **Expires on** on its edit form. Orders already booked are not affected.
- A member can't use the membership to pay for a performance after that date.
- The night after the Expires date, Stagemgr sets the membership to **Expired** and removes the member from the offer's MyEmma email group (unless they hold another current membership).
- If Stagemgr can't expire a membership (usually an old record with missing details), it emails the **membership notifications** address with a list and a link to each one. That membership stays Active, and can still be used, until the record is fixed. Stagemgr tries again every night.

To end a prepaid membership early, set its status to **Canceled** on its edit form. Refund the payment in Stripe if the patron is owed money.

### Gift subscriptions now stop billing when the gift ends

**Before:** a gift bought on a monthly or yearly membership kept charging the giver indefinitely, even though the purchase page said it would end.

**Now:** a gift subscription stops after the offer's **Gift duration** billing periods. A monthly offer with Gift duration `12` charges 12 times and then ends. Until then the membership shows **Cancel pending** with its final billing date, and afterwards it becomes **Canceled**. Offers with no Gift duration keep renewing as before.

This applies to gifts bought from now on. Gift subscriptions bought before this release keep renewing until they are cancelled in Stripe.

### What "Gift duration" means

The **Gift duration** field on a membership offer means one of two things, depending on the offer's Stripe price. The hint under the field says the same:

| Offer's Stripe price | Gift duration means | Blank means |
|---|---|---|
| **Recurring** (monthly, yearly …) | Billing cycles before a gift subscription ends | Renews until cancelled |
| **One-time** | Months the membership lasts, for every purchase | 12 months |

!!! warning "Check Gift duration when you switch an offer to a one-time price"
    An offer that was billed yearly with Gift duration `1` (one year) would last **one month** after switching to a one-time price. Set it to `12`.

---

## Bug Fixes

### Gift dates were being lost

When a buyer chose a **Keep secret until...** date for a gift membership, the date was thrown away. Every gift was treated as starting on the day it was bought, and the recipient was sent their member number straight away. This has affected gift orders since 2023. The date field is now the browser's standard date picker, and the date is kept.

### A patron is never left charged for a failed membership order

If something goes wrong after a prepaid membership's card charge, and the order can't be completed, Stagemgr now refunds the charge automatically and shows the patron an error. If that refund itself fails, it is written to the system log as needing a manual refund.

---

## For Administrators

- **Run the database update** included in this release before going live.
- **Add the nightly expiry job** (`ExpireOneTimeMembershipsJob`, 1:15 am) to the production `config/schedule.yml`.
- **Check `membership_notifications`** is set in `config/server.yml`. The alert about memberships that couldn't be expired goes there.
- **Before selling a one-time gift offer:** set its Price ID to the one-time Stripe price and set **Gift duration** to `12` for a one-year gift.
- **Review existing gift subscriptions.** Any that should end need to be cancelled in Stripe ("cancel at end of current period").

See [Membership Offers](../manual/offers/membership-offers.md#gift-memberships) and [Managing Memberships](../manual/ticketing/managing-memberships.md#one-time-memberships) in the manual for details.
