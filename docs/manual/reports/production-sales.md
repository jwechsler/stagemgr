# Production Sales by Performance

!!! info "Roles: All Users"
    This report is available to all authenticated users under the **Show Reports** permission group.

**Navigation:** Admin Menu > Reports > Production Sales by Performance

---

## Purpose

The Production Sales by Performance report provides a breakdown of ticket counts and revenue for
every performance of a selected production. Data is organized by ticket class, giving you a
detailed view of how each pricing tier performed at each show.

This report is useful for:

- Analyzing sales patterns across a production's run
- Comparing revenue by ticket class (e.g., full price vs. discount)
- Identifying high-performing and low-performing dates
- Providing summary data for production post-mortems

## Generating the Report

1. Navigate to **Admin Menu > Reports**.
2. In the **Production Sales by Performance** section, select a production from the dropdown.
3. Click **Show** to display results on screen, or **Download** to export a CSV file.

## Input Fields

| Field | Required | Description |
|---|---|---|
| **Production** | Yes | Select the production to report on from the dropdown list. Only productions you have permission to view are listed. |

## Output Format

### On-Screen Display

When you click **Show**, the report renders a table with one row per performance, optional
per-ticket-class count columns, and a subtotal row per production:

| Column | Description |
|---|---|
| **Performance Code / Date / Time** | Identifies the performance |
| *(ticket-class columns)* | One column per ticket class on the production showing the number sold at that performance. Columns are hidden if the class had zero sales across the run. |
| **Paid** | Total tickets sold (settled orders) for the performance |
| **Holds** | Tickets currently held (not yet sold) for the performance |
| **Max Ticket** | Highest available ticket price for the performance |
| **Gross** | Total cash collected — sum of every payment on every settled order for this performance, including credit card, cash, membership, flex pass, gift certificates, etc. Refund and exchange offsets are already netted in. |
| **Collected** | Subset of Gross that comes from payment types flagged as *reported as sales collected* (typically credit card and cash). Excludes membership and flex-pass payments, which are recorded for internal revenue tracking but don't represent fresh cash. |
| **Facility** | Ticketing fees: per-ticket fees from the ticket class plus any facility-fee service items on the order |
| **Processing** | Credit-card processing fees recorded on the payments |
| **Net** | **Collected − Facility − Processing**. What the house actually keeps after ticketing and processing costs. |

The report includes subtotals for each performance and a grand total row at the bottom summarizing
the entire production run.

### CSV Download

The CSV download contains the same columns as the on-screen display. The file can be opened in
Excel or any spreadsheet application for further analysis, charting, or sharing.

## What Is Included

- All settled ticket orders for the selected production (Processed, Fulfilled, Unclaimed, Refunded, Exchanged)
- Per-performance revenue, fees, and net
- Per-ticket-class counts (breakdown columns hidden when a class has zero sales)
- Summary totals per production

!!! note "Consistency across screens"
    **Gross** on this report is the same figure displayed as **Gross revenue** on the
    [Ticket Revenue Analysis](../analysis/ticket-revenue.md) screen and aggregated as
    **gross sales** on the [Rate of Sales Analysis](../analysis/rate-of-sales.md) screen.
    If the three ever disagree for a given production, check whether Rate of Sales is
    waiting on its next nightly run (see that page for details).

## Typical Use Cases

- **Post-production analysis**: Review which performances sold best and which ticket classes
  drove the most revenue.
- **Pricing strategy**: Compare sales volumes across ticket classes to evaluate whether discount
  tiers are priced correctly.
- **Board reporting**: Download the CSV and incorporate the data into production summary reports.
- **Budgeting**: Use historical data from past productions to forecast revenue for upcoming shows.

## Related Pages

- [Reports Overview](reports-overview.md)
- [Production Attendees](production-attendees.md)
- [Weekly Box Office](weekly-box-office.md)
