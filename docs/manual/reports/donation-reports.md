# Donation Reports

!!! info "Roles"
    **Donor Export (Donation Dump):** All Users (Show Reports permission)
    **Donation Totals:** Box Office, Admin (Box Office Reports permission)

**Navigation:** Admin Menu > Reports > Donor Export / Donation Totals

---

## Overview

Stagemgr provides two donation-related reports that serve different purposes. The **Donor Export**
generates a detailed list of individual donor contact information, while **Donation Totals**
provides a financial summary of donations grouped by theater.

---

## Donor Export (Donation Dump)

### Purpose

The Donor Export produces a CSV of donor contact information for a specified date range and
theater. It is designed for building mailing lists, importing into CRM systems, and generating
thank-you letter mail merges.

### Generating the Report

1. Navigate to **Admin Menu > Reports**.
2. In the **Donor Export** section, enter a **start date** and **end date**.
3. Select a **theater** from the dropdown.
4. Click **Generate**. The report runs as a background job.
5. When processing completes, you will receive an email with a download link. The report also
   appears in the **Generated Reports** section at the bottom of the Reports page.

### Input Fields

| Field | Required | Description |
|---|---|---|
| **Start Date** | Yes | Include donations on or after this date |
| **End Date** | Yes | Include donations on or before this date |
| **Theater** | Yes | Filter donations to a specific theater |

### Report Contents

| Column | Description |
|---|---|
| **Donor Name** | Full name of the donor |
| **Address** | Mailing address |
| **Phone** | Phone number |
| **Email** | Email address |
| **Donation Date** | Date of the donation |
| **Amount** | Donation amount |

!!! note "Background Job"
    This report runs as a background job and is delivered via email. Processing time depends on
    the number of donations in the selected range.

---

## Donation Totals

### Purpose

The Donation Totals report provides a financial summary of all donations within a date range,
broken down by theater. It includes fee information so you can see both gross donations and net
amounts after processing fees.

### Generating the Report

1. Navigate to **Admin Menu > Reports**.
2. In the **Donation Totals** section, enter a **start date** and **end date**.
3. Click **Show** to display results on screen, or **Download** to export a CSV.

### Input Fields

| Field | Required | Description |
|---|---|---|
| **Start Date** | Yes | Include donations on or after this date |
| **End Date** | Yes | Include donations on or before this date |

!!! warning "1-Month Maximum"
    The date range for Donation Totals is limited to 1 month. If you need a longer period,
    run the report multiple times with consecutive date ranges.

### Output Format

The report displays a summary table:

| Column | Description |
|---|---|
| **Theater** | The producing theater |
| **Donation Count** | Number of donations received |
| **Gross Donations** | Total donation amount before fees |
| **Processing Fees** | Credit card and payment processing fees |
| **Net Donations** | Donations after fees are subtracted |

### CSV Download

The CSV contains the same summary data and can be imported into a spreadsheet for further
analysis or inclusion in financial reports.

---

## Typical Use Cases

- **Year-end tax letters**: Use the Donor Export to generate a mailing list for annual donation
  acknowledgment letters.
- **Monthly financial reporting**: Use Donation Totals to report gross and net donation income
  to management.
- **CRM import**: Export donor contact information and import it into your donor management
  system.
- **Fee analysis**: Use the Donation Totals fee breakdown to evaluate the cost of processing
  donations.

## Related Pages

- [Reports Overview](reports-overview.md)
- [Daily Receipts](daily-receipts.md)
- [TRG Exports](trg-exports.md)
