# Membership Analysis

!!! info "Access"
    Available to **Admin** users only. Theater and Box Office users don't see the Pass
    Sales tab and can't open the page.

**Navigation:** Admin Menu > Analysis > Pass Sales

---

## What It Shows

Membership Analysis answers the question: *"Over this period, what did this membership
offer bring in, what did its members redeem, and what is one membership worth?"*

It uses the same rules as the [Membership Usage report](../reports/membership-reports.md#membership-usage),
so its memberships, members, Collected and $ redeemed figures agree with that report's
Memberships, Members, Collected and Paid for the same offers and dates. Where the report
works month by month, this page looks at the whole range at once and adds tenure and
per-membership figures.

## Running the Analysis

1. Open **Analysis** from the admin menu and click the **Pass Sales** tab.
2. In **Membership offers**, type part of an offer's name or tag and pick it from the
   suggestions. Repeat to add more offers, or pick an **All offers tagged …** suggestion to
   add every offer with that tag. Inactive offers are included and marked *(Inactive)*,
   and are listed after the active ones. Use **remove** or **Remove all** to change the
   selection.

   Type **all** or **active** for three shortcuts:

   | Shortcut | Adds |
   |---|---|
   | **All membership offers** | Every offer, active and inactive. |
   | **All active membership offers** | Every active offer. |
   | **Offers with active memberships in the selected dates** | Every offer, active or inactive, that had at least one membership active at some point between the **From** and **To** dates. It stays as one row and is worked out when you click **Run**, so changing the dates changes which offers it covers. |
3. Choose the **From** and **To** dates. Both dates are included. The default is the last
   12 months ending today.
4. Click **Run**. If you then change the offers or either date, the results disappear
   until you click **Run** again, so what's on screen always matches the choices above it.

Offers with nothing in the range (no memberships, and no money collected or redeemed) are
left out of the tables and named in a short note above them instead. An offer retired years
ago shows nothing for a recent range: widen the dates to see its history.

The page address includes your choices, so you can bookmark a run or send it to a
colleague.

## Results

Each table starts with a bold **Total** row across all the selected offers, followed by one
row per offer. Totals are worked out across every membership in the selection: the Total
average is the average over all those memberships, not an average of the offer averages.

### Memberships & members

| Column | Meaning |
|---|---|
| **Memberships in range** | Memberships that were active at any point between the From and To dates. |
| **Members in range** | The people those memberships admit. Each membership counts its offer's tickets per performance, so a dual membership is two members. |
| **Memberships active at end** | Memberships active on the **To** date. This is the end of your range, not today. |
| **Members active at end** | The people those memberships admit. |
| **New memberships** | Memberships that started during the range. |
| **Dropped memberships** | Memberships that ended during the range and are no longer active (see below for how a membership's end is decided). |
| **Average length** | The average length of the memberships that ended in the range and of those still active at its end, in months. Each is measured from its start date, including any time before the range: to its end if it ended, or to the **To** date if it is still active. |

A membership is active from its start date (the Stripe start date, or the member-since
date when there is none) through its end.

Payments decide when a membership ran, because some older records disagree with them
(memberships still marked **Pending** that paid for years, or payments after the recorded
end date):

- An **Active** membership with no end date is still running.
- Any other membership runs until the later of its end date and the date it is paid
  through (its last payment plus one billing period: a month, or a year for a yearly offer). A **Suspended** membership that stopped paying
  therefore counts only for the period it paid for. Refunds and $0 payments don't extend it.
- A **Pending** membership counts only if it has been paid; one that never paid never
  started.

### Money

| Column | Meaning |
|---|---|
| **Collected** | Money taken on the offer's membership purchase orders during the range, after refunds. |
| **Orders paid with membership** | Ticket orders paid with one of the offer's memberships during the range, including no-shows (unclaimed orders), since they still used the membership. Refunded and exchanged orders are not counted, so an exchange counts once, as its replacement order. |
| **$ redeemed** | The ticket value members redeemed with their memberships during the range. Refunds and exchanges net out. |
| **Net** | Collected less $ redeemed. |

### Per-membership economics, per month

One table covering every membership in range, showing how much each membership brings
in and pays out **per month** it was active in the range. For each membership:

- **Revenue / month** is the monthly rate its payments paid for the days it was active in
  the range (see below). A member who paid $29 every month shows $29.
- **Redeemed / month** is the ticket value it redeemed during the range, divided by the
  number of months it was active in the range, counting at least one month.
- **Net / month** is revenue per month less redeemed per month.

Each row shows how many memberships it covers, then the average, minimum and maximum of
each figure. The minimum and maximum show the member code they came from; click it to
open that membership. The Total row pools every membership of the selected offers.

How the figures are worked out:

- **Active months.** A membership's months run from the later of its start and the
  range's From date to the earlier of its end and the range's To date. Revenue uses that
  exact time, so a member who joined ten days before the To date still shows their full
  monthly price. Redemptions aren't spread, so for them a membership active
  less than a month counts as one month; otherwise one early ticket would read as a very
  large monthly figure.
- **Each payment is a monthly rate over the period it pays for.** A payment's rate is its
  amount divided by the months it pays for ($420 a year is $35 a month), and it applies
  to the billing period it covers. Revenue per month is the average of those rates across
  the membership's days in the range; days no payment covered count as $0, so a missed
  or refunded month lowers it. A yearly payment made before the range still counts for
  the days of the range it pays for.
- **Billing periods follow Stripe's calendar.** A monthly period runs from the
  subscription's billing day to the same day the next month, and a yearly one to the
  same date the next year. A billing day the month doesn't have (the 30th in February)
  falls on the month's last day, as Stripe bills it. A charge retried a few days late
  still pays for the period it was due for. Weekly and daily periods are fixed lengths.
- **Billing period.** The period comes from the offer's Stripe price (see **Billing
  period** on the [offer's page](../offers/membership-offers.md)). An offer without a
  Price ID, or whose period has not been read from Stripe, is assumed to bill monthly.
- **One-time prices** are spread across the membership's whole intended length,
  whatever the range: from its start to its end, or, while it is still running, for
  the offer's gift length (months when given as a gift) or, failing that, 12 months. A
  $120 one-year membership shows $10 a month even when the range covers only part of it.
  The 12-month default is an assumption; set the gift length on offers sold as a fixed
  term.
- **Refunds** count in the billing period they were issued in, as a negative rate, so a
  credit-back or partial refund lowers the month it happened rather than the month of the
  charge it reverses.
- **Redemptions** happen on a single day, so they are not spread: only redemptions
  during the range count.

The Money table above is unaffected: its Collected is still the cash taken in during
the range.

## Tips

- To compare offers side by side, select them together; each gets its own row under the
  Total.
- To check a single month against the Membership Usage report, set From and To to the
  first and last day of that month.
- A negative net means members redeemed more in tickets than they paid during the range.
