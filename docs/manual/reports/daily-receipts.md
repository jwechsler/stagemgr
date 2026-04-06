# Daily Receipts Report

!!! info "Roles: Box Office, Admin"
    This report is available under the **Box Office Reports** permission group.

**Navigation:** Admin Menu > Reports > Daily Receipts

---

## Purpose

The Daily Receipts report provides a day-by-day breakdown of all sales transactions within a
specified date range, organized by payment type. It is the primary tool for daily financial
reconciliation, allowing box office staff to verify that recorded sales match payment processor
records and cash drawer counts.

## Generating the Report

1. Navigate to **Admin Menu > Reports**.
2. In the **Daily Receipts** section, enter a **start date** and **end date**.
3. Click **Show** to display results on screen, or **Download** to export a CSV file.

## Input Fields

| Field | Required | Description |
|---|---|---|
| **Start Date** | Yes | The first date to include in the report |
| **End Date** | Yes | The last date to include in the report |

!!! warning "31-Day Maximum"
    The date range is limited to a maximum of 31 days. If you enter a range longer than 31 days,
    the system will display an error. For longer periods, run the report in multiple segments or
    use the Weekly Box Office report.

## Output Format

### On-Screen Display

The report renders a table showing daily totals broken down by payment type:

| Column | Description |
|---|---|
| **Date** | The transaction date |
| **Credit Card** | Total credit card payments processed that day |
| **Cash** | Total cash payments received |
| **Check** | Total check payments received |
| **Comp** | Total value of complimentary tickets issued |
| **Gift Certificate** | Total gift certificate redemptions |
| **External** | Total external payments (e.g., invoiced amounts) |
| **Daily Total** | Sum of all payment types for the day |

The report includes a grand total row at the bottom summarizing the full date range.

### CSV Download

The CSV download includes the same summary columns as the on-screen display, plus expanded
detail rows with full order-level information:

| Additional CSV Columns | Description |
|---|---|
| **Order ID** | Individual order identifier |
| **Customer Name** | Buyer name |
| **Production** | Production associated with the order |
| **Performance** | Specific performance date and time |
| **Ticket Class** | Ticket pricing tier |
| **Quantity** | Number of tickets in the order |
| **Amount** | Order total |
| **Payment Method** | Specific payment method used |
| **Transaction ID** | Payment processor reference number |

!!! tip "Full Detail in CSV"
    The CSV download contains significantly more detail than the on-screen summary. Use the
    download when you need order-level data for reconciliation or auditing.

## Typical Use Cases

- **Daily reconciliation**: Compare the credit card total against your Stripe dashboard or
  payment processor statement at the end of each business day.
- **Cash drawer balancing**: Verify that the cash total matches the physical cash count.
- **Auditing**: Use the detailed CSV to trace individual transactions when discrepancies arise.
- **Month-end close**: Run the report in weekly segments to compile monthly financial summaries.

## Tips

- Run this report at the end of each business day to catch discrepancies early.
- The **Download** option gives you order-level detail that is not visible in the on-screen
  summary. Always use the download for formal reconciliation work.
- If you need more than 31 days of data, run multiple reports and combine the CSVs in a
  spreadsheet.

## Related Pages

- [Reports Overview](reports-overview.md)
- [Weekly Box Office](weekly-box-office.md)
- [Donation Reports](donation-reports.md)
