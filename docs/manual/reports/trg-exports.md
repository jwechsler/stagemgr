# TRG Arts Exports

!!! info "Roles: All Users"
    TRGArts Production Export, TRGArts by Performance Date, and Donor Export are available
    to all users under the **Show Reports** permission group.

**Navigation:** Admin Menu > Reports > TRG Arts Exports

---

## Overview

Stagemgr provides three export reports designed for integration with external analytics and
CRM platforms. All three run as **background jobs** and deliver results via email. After
clicking **Generate**, the system queues the job. When complete, you receive an email with a
download link and the CSV appears in the **Generated Reports** section.

| Report | Input | Scope |
|---|---|---|
| **TRGArts Production Export** | Production selection | Attendee info for a single production |
| **TRGArts Export by Performance Date** | Date range | Buyer info across productions by attendance date |
| **Donor Export** | Date range + theater | Donor contact information |

---

## TRGArts Production Export

Generates a comprehensive attendee export for a single production, formatted for TRG Arts.

**Steps:** Select a **production** from the dropdown, then click **Generate**.

| Field | Required | Description |
|---|---|---|
| **Production** | Yes | Select the production to export |

The CSV includes buyer name, mailing address, email, ticket details (performance date, ticket
class, quantity), and order/payment information -- all formatted to TRG Arts specifications.

---

## TRGArts Export by Performance Date

Generates a buyer information export filtered by performance attendance date rather than by
production. Useful for cross-production audience analysis within a time window.

**Steps:** Enter a **start date** and **end date**, then click **Generate**.

| Field | Required | Description |
|---|---|---|
| **Start Date** | Yes | Include buyers who attended performances on or after this date |
| **End Date** | Yes | Include buyers who attended performances on or before this date |

The CSV includes buyer demographics, performance attendance date, production/venue details, and
ticket/order information for all performances in the date range.

!!! tip "Date Range vs. Production"
    Use the **Production Export** for a specific show. Use the **Performance Date** export for
    a cross-production view of audience activity over a time period.

---

## Donor Export

Generates a contact information export for donors within a date range, filtered by theater.
This report is also documented on the [Donation Reports](donation-reports.md) page.

**Steps:** Enter a **start date**, **end date**, and select a **theater**, then click **Generate**.

| Field | Required | Description |
|---|---|---|
| **Start Date** | Yes | Include donations on or after this date |
| **End Date** | Yes | Include donations on or before this date |
| **Theater** | Yes | Filter to donations for a specific theater |

---

## Email Filtering in Exports

All three exports include customer email addresses, subject to permission-based filtering:

| Role | Email Visibility |
|---|---|
| **Administrator** | All email addresses included |
| **Box Office** | All email addresses included |
| **Resident Company** | All email addresses included |
| **Theater User (Non-Resident)** | Only opted-in email addresses included |

For full details on email opt-in rules and MyEmma integration, see the
[Production Attendees](production-attendees.md) documentation.

!!! note "Processing Time"
    Large productions or wide date ranges may take several minutes to process. You can navigate
    away from the Reports page while the job runs.

## Typical Use Cases

- **TRG Arts analytics**: Upload exports for audience segmentation and engagement analysis.
- **Seasonal reporting**: Use Performance Date export for cross-production audience activity.
- **Donor CRM integration**: Export donor contacts for import into fundraising platforms.

## Related Pages

- [Reports Overview](reports-overview.md)
- [Production Attendees](production-attendees.md)
- [Donation Reports](donation-reports.md)
- [Membership Reports](membership-reports.md)
