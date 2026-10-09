# Stagemgr Release Notes — Membership Analysis (October 2026)

**For:** Administrators and Box Office staff

This release adds a way to analyse membership offers and a list of each member's ticket orders. It also makes the **Membership Usage** report more accurate, so some past figures in that report will change. Box office staff need only read **Redemptions on the membership page** and **Membership Usage report: some numbers will change**.

---

## New: Pass Sales analysis (Administrators)

**Analysis** now has two tabs. **Production Sales** holds the existing show analyses (Rate of Sales, Ticket Revenue, Audience) and works exactly as before. **Pass Sales** is new and shows how membership offers are performing over a period you choose. Pass Sales is for administrators only.

### Running it

1. Open **Analysis** from the admin menu and click **Pass Sales**.
2. Under **Membership offers**, start typing an offer's name and pick it from the suggestions. Add as many as you like. Retired offers are included and marked *Inactive*, and they are listed after the active ones.
3. For a shortcut, type **all** or **active**:
   - **All membership offers** adds every offer.
   - **All active membership offers** adds the offers currently on sale.
   - **Offers with active memberships in the selected dates** adds every offer that had members during your dates. It is worked out when you click **Run**, so changing the dates changes which offers it covers.
4. Choose the **From** and **To** dates. Both days are included.
5. Click **Run**.

If you change the offers or the dates afterwards, the results disappear until you click **Run** again. That way, what's on screen always matches the choices above it.

Each table starts with a bold **Total** row for everything you picked, followed by one row per offer. An offer with no activity in your dates doesn't get a row; it's named in a short note above the tables instead. To see a retired offer's history, set dates from when it was sold.

### What it shows

**Memberships & members**
- Memberships and members during the period, and those still active on the **To** date. A dual membership counts as two members.
- **New** and **dropped** memberships, and the **% change** from the start of the period to the end. Active at start + new − dropped = active at end.
- **Average length** of membership, in months. It covers members who left during the period and those still active at its end.

**Money**
- What members paid for their memberships during the period.
- How many ticket orders were paid with a membership (no-shows included) and what those tickets were worth.
- The difference between the two.

**Per-membership economics, per month**
- For each membership: what it brings in each month, what it pays out in tickets each month, and the difference. You see the average, the lowest and the highest. Click a member code to open that membership.
- A member who pays $35 a month shows $35 a month. A yearly payment is spread over its twelve months. A refund counts in the month it was issued.

### Billing period on the offer page

Each membership offer's page now shows its **Billing period** (for example *Every 1 month*), read from Stripe whenever the offer's Price ID is set or changed. Pass Sales uses it to spread payments over the months they pay for. An offer with no Price ID, mostly older offers, is treated as monthly.

The full guide is in the user manual under **Analysis → Membership Analysis**.

---

## New: Redemptions on the membership page

Open any membership from **Memberships** to see a new **Redemptions** table. It lists every order paid for in whole or in part with that membership, and works like **Order History** on a patron's page.

- **Amount** is the order's total. **Paid by membership** is the membership's share of it. When the two differ, the rest was paid another way.
- Exchanged and refunded orders stay on the list with their status. A refunded order's membership share shows $0.00. An exchanged order still shows its original share, and the replacement order has its own row.

---

## Membership Usage report: some numbers will change

The **Membership Usage** report now follows the same rules as Pass Sales, and the two agree for the same offers and dates. Running a past month again may give different figures than before:

- **Paid is lower in months with exchanges.** An order exchanged for another performance was counted twice: once for the original order and once for the replacement. It now counts once.
- **Memberships follow what was actually paid.** A member who stops paying (a **Suspended** membership) counts only for the period they paid for. Some older records, mostly from before the switch to Stripe, were marked **Pending** or had an end date even though the member kept paying. They now count for the months they paid for, so some past months show a few more memberships.
- Memberships that never paid and have no end date no longer count as active indefinitely.

The report's help page in the user manual explains the new rules.

---

## Bug Fixes

- **Opening an old membership order no longer changes its status.** Viewing a membership order from before the switch to Stripe used to mark the membership **Pending**, even when the member was paying. Its status now stays as it was.
- **Members who renew no longer drop out of the reports.** A member whose Stripe subscription ended and was later restarted kept their old end date, so the reports stopped counting them. Their end date is now cleared when Stripe shows them as active again.
