# New Feature: Email Performance Attendees

## Overview

You can now send custom email messages to all ticket holders for a specific performance directly from the production management screen. This powerful new tool allows you to communicate important updates, venue changes, or special information to your audience efficiently.

## How to Use

1. **Navigate to a Production**: Go to Admin → Theaters → [Select Theater] → [Select Production]

2. **Find the Performance**: Locate the specific performance in the performances list

3. **Click "Email Attendees"**: You'll see a new button next to each performance

4. **Compose Your Message**:
   - **Subject**: Pre-filled with "Important update regarding [Production] on [Date]" (editable)
   - **From Address**: Choose between box office email or your personal email
   - **Message Body**: Write your custom message (supports Markdown formatting)

5. **Review Recipient Count**: The system automatically shows how many people will receive the email

6. **Send**: Click "Send Email to X Recipients" and confirm

## Who Receives the Email?

The system automatically sends to all ticket holders with:
- Order status: Hold, Processed, Processing, or Fulfilled
- Valid email addresses on file
- Non-placeholder addresses (excludes test orders)

## Email Content

Recipients receive a clean, focused email containing:
- Theater Wit header and branding
- Personal greeting ("Hi [First Name],")
- Your custom message
- Sidebar with "Also Playing" and contact information

**Note**: Order confirmation details are NOT included - this keeps the message focused on your announcement.

## Markdown Formatting

You can use Markdown to format your messages:

```markdown
**Bold text** for emphasis
*Italic text* for subtle emphasis

## Headings for sections

- Bullet points
- For lists

[Link text](https://example.com) for links
```

## Use Cases

- **Venue Changes**: "Tonight's performance has been moved to the upstairs theater"
- **Weather Alerts**: "Due to snow, we recommend arriving 15 minutes early"
- **Special Guests**: "Join us for a post-show Q&A with the director"
- **Parking Updates**: "Street parking will be limited due to neighborhood event"
- **Pre-Show Information**: "Please note this performance includes strobe lighting"
- **Last-Minute Updates**: Any time-sensitive information for specific performance attendees

## Best Practices

✅ **Do:**
- Send timely, relevant information
- Keep messages concise and actionable
- Use the pre-filled subject line or edit it to be clear and specific
- Test with a small performance first if you're uncertain
- Use Markdown formatting for better readability

❌ **Don't:**
- Send promotional content (use other marketing channels)
- Send duplicate messages (emails are sent immediately)
- Include information that applies to all performances (use general announcements instead)

## Technical Details

- **Delivery**: Emails are queued and sent within minutes
- **Tracking**: Each broadcast is logged with timestamp and recipient count
- **Retry Logic**: Failed emails automatically retry up to 8 times
- **From Address**: Must be a verified sender (box office or your email)

## Questions or Issues?

If you encounter any problems or have questions about using this feature, please contact the technical team or submit a support request through the admin dashboard.

---

*Feature added: February 2026*
