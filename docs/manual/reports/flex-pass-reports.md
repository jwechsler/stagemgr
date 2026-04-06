# FlexPass Reports

!!! info "Roles"
    **FlexPass Sales:** Box Office, Admin (Reconciliation Reports permission)
    **FlexPass Patron Report:** Box Office, Admin (Box Office Reports permission)

**Navigation:** Admin Menu > Reports > FlexPass Sales / FlexPass Patron Report

---

## Overview

Stagemgr provides two FlexPass-related reports. **FlexPass Sales** tracks FlexPass purchasing
and redemption trends by month. **FlexPass Patron Report** provides a detailed per-patron
export with codes, expiration dates, and remaining admissions.

---

## FlexPass Sales

### Purpose

The FlexPass Sales report summarizes FlexPass activity over a date range, broken down by month.
It shows purchase volumes and usage patterns, making it useful for tracking the financial
performance of FlexPass offerings.

### Generating the Report

1. Navigate to **Admin Menu > Reports**.
2. In the **FlexPass Sales** section, enter a **start date** and **end date**.
3. Optionally, select a specific **offer** from the dropdown to filter results to a single
   FlexPass offer.
4. Click **Show** to display results on screen, or **Download** to export a CSV.

### Input Fields

| Field | Required | Description |
|---|---|---|
| **Start Date** | Yes | Include FlexPass activity on or after this date |
| **End Date** | Yes | Include FlexPass activity on or before this date |
| **Offer** | No | Filter to a specific FlexPass offer. Leave blank to include all offers. |

### Output Format

| Column | Description |
|---|---|
| **Month** | The calendar month |
| **FlexPasses Sold** | Number of FlexPasses purchased |
| **Revenue** | Total revenue from FlexPass sales |
| **Redemptions** | Number of FlexPass ticket redemptions |
| **Usage Rate** | Percentage of available admissions that have been redeemed |

!!! tip "Offer Filter"
    If you run multiple FlexPass offerings (e.g., 4-show pass, 6-show pass), use the offer
    filter to see performance data for each type separately.

---

## FlexPass Patron Report

### Purpose

The FlexPass Patron Report provides a comprehensive export of FlexPass orders within a specified
date range, including patron contact information, FlexPass details, expiration dates, and usage
status. This report is essential for FlexPass management, patron communication, and customer
service operations.

### Generating the Report

1. Navigate to **Admin Menu > Reports**.
2. In the **FlexPass Patron Report** section, enter a **start date** and **end date**.
3. Click **Show** to display results on screen, or **Download** to export a CSV.

### Input Fields

| Field | Required | Description |
|---|---|---|
| **Start Date** | Yes | Include FlexPass orders created on or after this date |
| **End Date** | Yes | Include FlexPass orders created on or before this date |

The date range is inclusive of both start and end dates.

### Report Contents

The report includes the following information for each FlexPass order:

| Column | Description |
|---|---|
| **FlexPass Order Number** | Unique identifier for the FlexPass order |
| **Patron Name** | Customer's full name from the order |
| **Email** | Customer's email address |
| **Phone** | Customer's phone number (if available) |
| **FlexPass Code** | The unique code assigned to the FlexPass for redemption |
| **Expiration Date** | When the FlexPass expires (formatted as MM/DD/YYYY) |
| **Admissions Remaining** | Number of ticket redemptions remaining on the FlexPass |
| **Fulfilled** | Whether the FlexPass order has been processed ("Y" for fulfilled, "N" for pending) |

### File Naming Convention

Downloaded CSV files are automatically named using the format:
`flex_pass_patron_report_YYYYMMDD_YYYYMMDD.csv`
where the dates represent the start and end dates of the report range.

---

## Typical Use Cases

- **Customer service**: Look up FlexPass details when customers call with questions about their
  remaining admissions or expiration dates.
- **Expiration management**: Identify FlexPasses approaching expiration for proactive outreach.
- **Usage tracking**: Monitor FlexPass utilization with the Sales report over time.
- **Marketing**: Contact FlexPass holders with targeted promotions for upcoming productions.
- **Reconciliation**: Track FlexPass sales and redemption patterns using the monthly Sales report.
- **Fulfillment**: Identify pending FlexPass orders requiring processing (Fulfilled = "N").

## Related Pages

- [Reports Overview](reports-overview.md)
- [Membership Reports](membership-reports.md)
- [Weekly Box Office](weekly-box-office.md)
