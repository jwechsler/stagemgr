# Email Configuration

!!! info "Required Role"
    Email configuration is managed at the server level by **system administrators**. The MyEmma group ID on each theater is automatically managed but can be viewed by **Administrators** and **Box Office** staff.

## Overview

Stagemgr sends several types of automated emails as part of order processing and patron communication:

- **Ticket confirmation emails** -- Sent when a ticket order is processed
- **Follow-up emails** -- Sent after a performance date
- **Flex pass receipts** -- Sent when a flex pass order is processed
- **Membership receipts** -- Sent when a membership order is processed
- **Donation receipts** -- Sent when a donation order is processed
- **Performance broadcast emails** -- Sent manually by staff to all attendees of a specific performance
- **Report delivery emails** -- CSV report exports sent to the requesting staff member

## System Email Addresses

The following email addresses are configured at the server level and used as sender addresses for automated emails:

| Address | Purpose |
|---------|---------|
| **Box Office** | Default "from" address for most patron-facing emails |
| **Online Errors** | Receives notifications about online order processing errors |
| **Flex Pass Notifications** | Receives notifications about flex pass activity |
| **Membership Notifications** | Receives notifications about membership activity |
| **Supervisor Notifications** | Receives high-priority system notifications |
| **Wheelchair Conversion Notifications** | Receives alerts when seats are converted to wheelchair-accessible |
| **Software Address** | System administrative emails |

These addresses are configured in the server configuration file and cannot be changed through the admin interface. Contact your system administrator to modify them.

## MyEmma Integration

Stagemgr integrates with the **MyEmma** email marketing platform to manage attendee mailing lists. When enabled, this integration provides:

### Automatic Group Creation

- When a new **theater** is created, Stagemgr automatically creates a MyEmma group named "[Theater Name] Attendee"
- The group ID is stored on the theater record in the **MyEmma attendee group** field
- When configured, new **productions** can also create corresponding MyEmma groups

### Attendee Sync

When a patron purchases tickets and opts into the email list, Stagemgr automatically adds them to the appropriate MyEmma group for that theater's attendees. This keeps your email marketing lists in sync with actual ticket buyers.

### Email Opt-In Status

Patron email addresses are filtered based on MyEmma opt-in status:

- Reports include an `opted_in_for_email` field ("Y" or "N")
- **Administrators** and **Box Office** staff see all email addresses regardless of opt-in status
- **Resident Company Theater Users** see all email addresses
- **Other Theater Users** only see email addresses for patrons who have opted in

If MyEmma is disabled or not configured, opt-in status defaults to "N" for all patrons.

### Configuration

MyEmma integration is configured at the server level:

| Setting | Description |
|---------|-------------|
| `create_production_groups` | Whether to automatically create MyEmma groups for new productions |
| `create_theater_groups` | Whether to automatically create MyEmma groups for new theaters |

When MyEmma is disabled, all email marketing features are skipped silently -- order processing and patron management continue normally.

## Email Suppression via Payment Types

Certain automated emails can be suppressed for specific payment types. For example, you might want to skip sending a confirmation email for complimentary orders. This is configured through **Order Task Suppressions** on each payment type.

See [Payment Types](payment-types.md) for details on configuring email suppression.

## Production-Specific Email Content

Each production can include custom messages in confirmation and follow-up emails:

- **Additional Confirmation Message** -- Added to the ticket confirmation email
- **Additional Follow-Up Message** -- Added to the post-performance follow-up email

Both fields support Markdown formatting. Use the **Send sample email** feature on the production edit page to preview how these messages appear.

See [Email Templates](../advanced/email-templates.md) for details on customizing email content.
