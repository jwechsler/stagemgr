# TRG Arts Exports

!!! info "Roles: All Users (except where noted)"
    TRGArts Production Export, TRGArts Export by Performance Date, and Donor export are available
    to all users under the **Show Reports** permission group. **First Time Attendees (TRG)** is
    limited to Box Office and Administrator users.

**Navigation:** Admin Menu > Reports > TRG Arts Exports

---

## Overview

Stagemgr provides four export reports designed for integration with external analytics and
CRM platforms. All four run as **background jobs** and deliver results via email. After
clicking **Generate**, the system queues the job. When complete, you receive an email with a
download link and the CSV appears in the **Generated Reports** section.

| Report | Input | Scope |
|---|---|---|
| **TRGArts Production Export** | Production selection | Attendee info for a single production |
| **TRGArts Export by Performance Date** | Date range | Buyer info across productions by attendance date |
| **First Time Attendees (TRG)** | Single date | Patrons whose first-ever attendance falls on or after the date |
| **Donor export** | Date range + theater | Donor contact information |

---

## TRGArts Production Export

Generates a comprehensive attendee export for a single production, formatted for TRG Arts.

**Steps:** Search for a **production** with the [production picker](../productions/finding-productions.md#the-production-search-picker), then click **Generate**.

| Field | Required | Description |
|---|---|---|
| **Production** | Yes | Search for the production to export |

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

## First Time Attendees (TRG)

!!! info "Roles: Box Office, Administrator"
    This export is part of the **Box Office Reports** permission group and does not appear for
    theater users.

Exports contact information for patrons who attended a show **for the first time ever** on or
after a given date -- a ready-made outreach list for converting first-timers into repeat
audience members through special offers or communication.

![First Time Attendees report form with the First Attendance On or After date field](../assets/images/screenshots/first-time-attendees-form.png)

**Steps:** Enter a **First Attendance On or After** date, then click **Generate**.

| Field | Required | Description |
|---|---|---|
| **First Attendance On or After** | Yes | A patron's first-ever attendance must fall between this date and today |

### Who is included

A patron appears in the export when **all** of the following are true:

- Their **first-ever attendance** -- counting visits of any kind (complimentary, membership,
  or flex pass) at **any theater** -- falls on or after the report date. A patron who attended
  anything before the date is never included, no matter how often they have come since.
- They have at least one **fulfilled** order containing a paid (non-complimentary) ticket that
  was **not** purchased with a flex pass or a standard membership. Attendances on a **timed
  membership** ("library pass") count as qualifying.
- They are contactable: the address record has a street address or an email.
- The address is not flagged as a **placeholder** ("not a ticket buyer").

!!! note "Multiple visits are fine"
    Patrons who have attended several times since the date are still included -- only their
    *first* visit has to fall inside the window. The first visit may itself have been a comp
    or pass visit; what must be fulfilled and paid is at least one of their orders.

### Output format

The CSV uses the standard TRG Arts import columns plus two extras:

| Column | Value |
|---|---|
| **Segment** | `STB` (single-ticket buyer) |
| **Season** | The year of the report date |
| **Title** | `First Time Attendee as of MM/DD` (the report date, no year) |
| **FirstAttendedDate** | Date of the patron's first attendance |
| **FirstAttendedTheatre** | Theater where that first attendance took place |

Because the report is restricted to Box Office and Administrator users, customer email
addresses are always included in the file.

---

## Donor export

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

The exports include customer email addresses, subject to permission-based filtering
(First Time Attendees always includes emails, since only Box Office and Administrator
users can run it):

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
- **First-timer outreach**: Use First Time Attendees to build a welcome-offer or follow-up
  communication list of brand-new patrons.
- **Donor CRM integration**: Export donor contacts for import into fundraising platforms.

## Related Pages

- [Reports Overview](reports-overview.md)
- [Production Attendees](production-attendees.md)
- [Donation Reports](donation-reports.md)
- [Membership Reports](membership-reports.md)
