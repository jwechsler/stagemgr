# New Feature: Sample Email Preview for Productions

## Overview

When editing a production, box office staff can now send themselves a sample **confirmation email** or **follow-up email** to preview exactly what patrons will receive. The sample emails use the current form values — including any unsaved edits — so you can refine your message before saving.

## Who Can Use This

This feature is available to **box office staff and administrators** only.

## When Is It Available?

The "Send sample confirmation email" and "Send sample follow-up email" buttons appear on the **Edit Production** page, directly below their respective message fields:

- **Send sample confirmation email** — below the "Additional Confirmation Message" field
- **Send sample follow-up email** — below the "Additional follow up message" field

The buttons only appear for productions that have already been saved (not on the New Production form).

## How to Use

1. **Navigate to the production edit page** (Admin → Theater → Production → Edit)

2. **Enter or modify the message** in the "Additional Confirmation Message" or "Additional follow up message" text area

3. **Click the corresponding "Send sample..." button** — a confirmation dialog will appear showing the email address the sample will be sent to (your admin account email)

4. **Confirm the send** — the button will briefly show "Sending..." while the email is delivered

5. **Check your inbox** — the sample email arrives within a few seconds, rendered exactly as a patron would see it

6. **Iterate as needed** — adjust the message text and send another sample without saving or reloading the page

## What the Sample Email Contains

| Element | Value |
|---------|-------|
| Recipient | Your admin account email address |
| Production name | Current value from the Name field on the form |
| Confirmation/follow-up message | Current value from the textarea (even if unsaved) |
| Patron name | "Sample Customer" |
| Performance date | One week from today at 7:30 PM |
| Number of tickets | 2 tickets |
| Ticket price | $35.00 General Admission |
| Total charge | $70.00 |

## Important Notes

- The sample uses your **current form values**, not the last saved version — you do not need to save the production first
- No data is permanently created — the system builds temporary records to render the email, then automatically cleans them up
- The page does **not reload** when you send a sample, so any other form edits you've made are preserved
- Markdown formatting in the message fields is rendered in the sample email, so you can verify links, bold text, lists, etc.

## Use Cases

- Preview a new confirmation message before a production goes on sale
- Test markdown formatting in follow-up messages (links, bold, lists)
- Verify that the email layout looks correct with your custom content before patrons see it
- Quickly iterate on message wording by sending multiple samples without saving

## Questions or Issues?

If you encounter any problems or have questions about using this feature, please contact the technical team or submit a support request through the admin dashboard.

---

*Feature added: March 2026*
