# Changelog

!!! info "Reference"
    Recent feature additions and significant changes to Stagemgr, listed from newest to oldest.

## March 2026

### Refund to Donation

**Available to:** Administrator, Box Office

A new action on ticket orders that converts a ticket purchase directly into a tax-deductible donation in a single step.

| Detail | Description |
|--------|-------------|
| **Where** | Ticket order detail page, in the red action group alongside Refund and Cancel |
| **Requirements** | Order must be Processed or Fulfilled, paid with a currency payment type (cash, check, or credit card), and the theater must be a 501(c)(3) |
| **Not available for** | Orders paid with Flex Pass or Membership |

**What happens when you click Refund to Donation:**

1. All reserved seats are released back to available inventory
2. Ticket line items are removed from the original order
3. A new donation order is created for the full amount paid
4. The original payment is moved to the donation order
5. The original ticket order is marked as Canceled with a note referencing the donation order
6. A donation receipt email is sent to the patron

!!! warning "Irreversible"
    This action cannot be undone. To reverse it, you would need to refund the donation order separately and re-enter the ticket order.

**Use cases:** Patron donates tickets they cannot use. Patron unable to exchange who prefers to donate. Partial group donation (use Split Order first, then Refund to Donation on the portion).

---

### Sample Email Preview

**Available to:** Administrator, Box Office

New buttons on the production edit page let you send yourself a sample confirmation email or follow-up email to preview exactly what patrons will see.

| Detail | Description |
|--------|-------------|
| **Where** | Edit Production page, below the "Additional Confirmation Message" and "Additional follow up message" fields |
| **Buttons** | "Send sample confirmation email" and "Send sample follow-up email" |
| **Requirements** | Production must be saved (not available on New Production form) |

**Key behaviors:**

- Uses your **current form values**, including unsaved edits -- you do not need to save first
- The page does not reload, preserving any other form changes
- Sample email includes placeholder data (Sample Customer, 2 tickets at $35, performance one week from today)
- Markdown formatting is rendered in the sample
- No permanent data is created -- temporary records are cleaned up automatically

**Use cases:** Preview confirmation messages before a show goes on sale. Test Markdown formatting. Iterate on messaging by sending multiple samples without saving.

---

## February 2026

### Performance Broadcast Email

**Available to:** Administrator, Box Office

Send custom email messages to all ticket holders for a specific performance directly from the production management screen.

| Detail | Description |
|--------|-------------|
| **Where** | Theaters > [Theater] > [Production] > Performances list, "Email Attendees" button on each performance |
| **Recipients** | All ticket holders with orders in Hold, Processed, Processing, or Fulfilled status who have valid email addresses |
| **From address** | Box office email or your personal email (must be a verified sender) |

**Features:**

- Pre-filled subject line (editable): "Important update regarding [Production] on [Date]"
- Markdown formatting support in the message body
- Recipient count displayed before sending
- Clean email layout with theater branding and greeting
- Emails queued and sent within minutes with automatic retry (up to 8 times)

**Use cases:** Venue changes, weather alerts, special guest announcements, parking updates, pre-show information, any time-sensitive communication for a specific performance's audience.

!!! tip "Best Practice"
    Use broadcast emails for timely, relevant operational information. For promotional content, use your regular marketing channels (MyEmma, social media).

---

## Earlier Changes

For information about features added before February 2026, contact your system administrator or refer to the internal release notes.
