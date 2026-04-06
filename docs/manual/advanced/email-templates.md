# Email Templates

!!! info "Required Role"
    **Administrator** or **Box Office** can customize production email messages and send sample previews.

**Navigation:** Theaters > [Theater Name] > [Production Name] > Edit

## Overview

Every production in Stagemgr can include custom messages in two types of automated patron emails: the **confirmation email** sent when an order is placed, and the **follow-up email** sent after the performance. These messages are configured on the production edit page and support Markdown formatting for rich content.

## Confirmation Email Message

The confirmation email is sent automatically when a patron's ticket order is processed. It includes standard order details (performance date, seats, total) plus your custom message.

### Configuring the Message

1. Navigate to the production edit page
2. Locate the **Additional Confirmation Message** text area
3. Enter your custom message content
4. Click **Update Production** to save

The message you enter is inserted into the confirmation email template below the order details and above the standard footer. It appears in every confirmation email for this production.

### Common Uses

- Parking and arrival instructions
- Venue-specific information (accessibility, restrooms, concessions)
- Pre-show dining recommendations or partnerships
- Content warnings or audience advisories
- Links to digital programs or cast information

## Follow-Up Email Message

The follow-up email is sent after a performance date has passed. It thanks patrons for attending and can include your custom message.

### Configuring the Message

1. Navigate to the production edit page
2. Locate the **Additional follow up message** text area
3. Enter your custom message content
4. Click **Update Production** to save

### Common Uses

- Survey links for audience feedback
- Upcoming show announcements and cross-promotion
- Social media sharing requests
- Donation appeals
- Information about the next production in the season

## Markdown Formatting

Both message fields support **Markdown** syntax, which is rendered as formatted HTML in the email. This allows you to include rich content without writing HTML.

| Markdown Syntax | Result |
|-----------------|--------|
| `**bold text**` | **bold text** |
| `*italic text*` | *italic text* |
| `[Link text](https://example.com)` | Clickable link |
| `- Item one` | Bulleted list |
| `1. First item` | Numbered list |
| `## Heading` | Section heading |

!!! tip "Keep It Simple"
    Email clients vary in their HTML rendering. Stick to basic formatting -- bold, italic, links, and lists -- for the most consistent results across email clients.

## Sample Email Preview

You can preview exactly what patrons will see by sending yourself a **sample email** before the production goes on sale or before saving changes.

### How to Send a Sample

1. Navigate to the production edit page
2. Enter or modify the message in the confirmation or follow-up text area
3. Click **Send sample confirmation email** or **Send sample follow-up email** (the button appears directly below each message field)
4. A confirmation dialog shows the email address the sample will be sent to (your admin account email)
5. Confirm the send -- the button briefly shows "Sending..." while the email is delivered
6. Check your inbox -- the sample arrives within a few seconds

!!! note "Unsaved Changes Are Included"
    The sample email uses your **current form values**, not the last saved version. You do not need to save the production first. This lets you iterate on the message and preview multiple drafts without saving.

### What the Sample Email Contains

| Element | Value |
|---------|-------|
| **Recipient** | Your admin account email address |
| **Production name** | Current value from the Name field on the form |
| **Confirmation/follow-up message** | Current value from the text area (even if unsaved) |
| **Patron name** | "Sample Customer" |
| **Performance date** | One week from today at 7:30 PM |
| **Number of tickets** | 2 tickets |
| **Ticket price** | $35.00 General Admission |
| **Total charge** | $70.00 |

### Key Behaviors

- The page **does not reload** when you send a sample -- any other form edits are preserved
- No data is permanently created -- temporary records are built to render the email and then cleaned up
- Markdown formatting is rendered in the sample, so you can verify links, bold text, and lists
- You can send multiple samples in a row to compare different versions

!!! warning "Sample Button Availability"
    The sample email buttons only appear for productions that have already been saved. They are not available on the New Production form. Create the production first, then use the edit page to preview emails.

## Email Template Workflow

A recommended workflow for setting up production emails:

1. **Create the production** with basic information
2. **Write the confirmation message** with venue instructions and pre-show details
3. **Send a sample confirmation email** to yourself and review it
4. **Adjust and resend** until the message looks right
5. **Write the follow-up message** with survey links and upcoming show info
6. **Send a sample follow-up email** to yourself and review it
7. **Save the production** once both messages are finalized
8. **Check again after saving** by sending one more sample to confirm the saved version is correct
