# Production Attendees Report

!!! info "Roles: All Users"
    This report is available to all authenticated users under the **Show Reports** permission group.
    However, email address visibility depends on your role (see Email Address Inclusion Rules below).

**Navigation:** Admin Menu > Reports > Production Attendees

---

## Purpose

The Production Attendees report provides a comprehensive export of all ticket buyers for a
specific production, including customer contact information, ticket details, and payment data.
This report is essential for post-show marketing, customer relationship management, and business
analysis.

## Generating the Report

1. Navigate to **Admin Menu > Reports**.
2. In the **Production Attendees** section, search for and select a production using the [production picker](../productions/finding-productions.md#the-production-search-picker).
3. Click **Download** to generate and download a CSV file.

## Input Fields

| Field | Required | Description |
|---|---|---|
| **Production** | Yes | Search by name, season, code, or theater. Only productions you have permission to view appear. |

## Report Contents

The CSV includes the following information for each ticket order:

| Column | Description |
|---|---|
| **Customer Information** | Name, address, phone number, and email address |
| **Order Details** | Order ID, date, status, and special offer codes used |
| **Ticket Information** | Performance code, ticket class, number of tickets and seats |
| **Financial Data** | Order total, revenue (excluding fees), processing fees, and facility fees |
| **Seating** | Seat assignments (for productions with reserved seating) |
| **Email Marketing Status** | Whether the customer has opted into the theater's email list |

## Email Address Inclusion Rules

Email addresses are included in the report based on a combination of your user permissions and
the customer's email opt-in status. This ensures customer privacy is respected while enabling
legitimate marketing use.

### Users Who Receive All Email Addresses

The following roles have full access to all customer email addresses in the report:

- **Administrators** -- full access to all customer email addresses
- **Box Office Staff** -- full access to all customer email addresses
- **Resident Company Users** -- full access to all customer email addresses

### Users With Limited Email Access

- **Theater Users (Non-Resident)** -- only receive email addresses for customers who have
  explicitly opted into the theater's email marketing list

### Email Opt-In Status Field

Each record includes an `opted_in_for_email` field:

| Value | Meaning |
|---|---|
| **Y** | Customer has opted into email marketing. Their address is included regardless of the requesting user's permissions. |
| **N** | Customer has not opted in. Their email address is only included for users with full email permissions (Admin, Box Office, Resident Company). |

## MyEmma Integration

The system integrates with the MyEmma email marketing platform to determine opt-in status:

- If MyEmma is enabled and configured, the system checks against the production's designated
  email group to determine whether each customer has opted in.
- If MyEmma is disabled or not configured, opt-in status defaults to **"N"** for all customers.
- Email addresses are then filtered based on user permissions as described above.

!!! warning "MyEmma Configuration"
    If your theater uses MyEmma for email marketing, make sure the production is associated with
    the correct email group. Otherwise all customers will show as not opted in, and non-resident
    theater users will not see any email addresses in the export.

## Data Privacy

This report contains sensitive customer information and should be handled according to your
organization's data privacy policies. Email addresses are filtered based on both customer consent
(opt-in status) and user authorization levels to protect customer privacy while enabling legitimate
business operations.

!!! note "Theater-Specific Permissions"
    The report respects theater-specific permissions. Users only see data for productions within
    their authorized theaters.

## Typical Use Cases

- **Post-show marketing**: Contact attendees about upcoming productions at the same venue.
- **Customer relationship management**: Build patron profiles using order and attendance data.
- **Business analysis**: Analyze ticket class distribution and revenue patterns per customer.
- **Email list building**: Export opted-in customers to your email marketing platform.

## Related Pages

- [Reports Overview](reports-overview.md)
- [Production Sales By Performance](production-sales.md)
- [TRG Exports](trg-exports.md)
