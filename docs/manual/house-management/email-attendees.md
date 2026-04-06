# Email Attendees

!!! info "Role: Managers, Administrators"
    The Email Attendees feature allows you to send custom email messages to all ticket holders for a specific performance. Use this for time-sensitive communications such as venue changes, weather alerts, or special announcements.

**Navigation:** Admin > Theaters > [Select Theater] > [Select Production] > Performances > Email Attendees

---

## Overview

You can send custom email messages to all ticket holders for a specific performance directly from the production management screen. This tool allows you to communicate important updates, venue changes, or special information to your audience efficiently.

---

## How to Use

1. **Navigate to a Production**: Go to Admin > Theaters > [Select Theater] > [Select Production].
2. **Find the Performance**: Locate the specific performance in the performances list.
3. **Click "Email Attendees"**: You will see a button next to each performance.
4. **Compose Your Message**:
   - **Subject**: Pre-filled with "Important update regarding [Production] on [Date]" (editable).
   - **From Address**: Choose between the box office email or your personal email.
   - **Message Body**: Write your custom message. Markdown formatting is supported.
5. **Review Recipient Count**: The system automatically shows how many people will receive the email.
6. **Send**: Click "Send Email to X Recipients" and confirm.

!!! warning
    Emails are sent immediately upon confirmation and cannot be recalled. Always double-check the recipient count and message content before clicking Send.

---

## Who Receives the Email?

The system automatically identifies and sends to all ticket holders who meet these criteria:

| Criteria | Detail |
|----------|--------|
| Order status | Hold, Processing, Processed, or Fulfilled |
| Email address | Must have a valid email on file |
| Record type | Non-placeholder addresses only (excludes test orders) |

Patrons with placeholder address records and those without email addresses are excluded.

---

## Email Content

Recipients receive a clean, focused email containing:

| Section | Content |
|---------|---------|
| Header | Theater Wit branding |
| Greeting | Personal greeting ("Hi [First Name],") |
| Body | Your custom message, rendered from Markdown |
| Sidebar | "Also Playing" listings and contact information |

Order confirmation details are **not** included. This keeps the message focused on your announcement rather than confusing it with a transactional email.

---

## Markdown Formatting

You can use Markdown to format your messages:

| Syntax | Result |
|--------|--------|
| `**Bold text**` | **Bold text** for emphasis |
| `*Italic text*` | *Italic text* for subtle emphasis |
| `## Heading` | Section headings |
| `- Item` | Bullet point lists |
| `[Link text](https://example.com)` | Clickable hyperlinks |

---

## Common Use Cases

| Scenario | Example Message |
|----------|----------------|
| Venue change | "Tonight's performance has been moved to the upstairs theater" |
| Weather alert | "Due to snow, we recommend arriving 15 minutes early" |
| Special guest | "Join us for a post-show Q&A with the director" |
| Parking update | "Street parking will be limited due to a neighborhood event" |
| Content advisory | "Please note this performance includes strobe lighting" |
| Schedule change | "Tonight's performance will begin 15 minutes late" |

---

## Best Practices

!!! tip
    - Send timely, relevant information specific to the performance.
    - Keep messages concise and actionable.
    - Use the pre-filled subject line or edit it to be clear and specific.
    - Test with a smaller performance first if you are uncertain about the formatting.
    - Use Markdown formatting for readability.

Avoid the following:

- Sending promotional content (use other marketing channels for that).
- Sending duplicate messages (emails are dispatched immediately with no deduplication).
- Including information that applies to all performances (use general announcements instead).

---

## Technical Details

| Detail | Description |
|--------|-------------|
| Delivery | Emails are queued and sent within minutes |
| Tracking | Each broadcast is logged with timestamp and recipient count |
| Retry logic | Failed emails automatically retry up to 8 times |
| From address | Must be a verified sender (box office email or your email) |

---

## Related Pages

- [Daily Operations](daily-operations.md) -- Where attendee communication fits in the day-of-show workflow
- [House Counts](house-counts.md) -- Check attendance numbers before sending
- [House Management Report](house-management-report.md) -- Identify special guests in the audience
