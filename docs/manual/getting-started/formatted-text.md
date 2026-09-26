# Formatted Text Fields

Many admin fields accept **Markdown** formatting: production descriptions, confirmation and follow-up messages, ticket class annotations, special feature text, offer descriptions, festival descriptions and the Email Attendees message. Each of them uses the same editor, so you can format text without memorising the syntax and see the result before you save.

## Preview First

A formatted field shows its text **as patrons will see it**, under a header reading **Preview (click to edit)**. The raw text stays out of the way until you need it, so a form with several long fields stays easy to scan.

- **Click the preview** (or its header) to open the editor below it.
- The preview stays in place and **updates as you type**.
- Click **Done**, or press **Escape** in the text box, to close the editor again.
- A field that failed validation opens already expanded, so you can see what to fix.

!!! note "Nothing changes until you save"
    Opening, editing and previewing a field never saves it. Changes are stored only when you save the form, exactly as before.

## The Toolbar

The toolbar above the text box inserts the Markdown for you. Select some text first to format it, or click a button with nothing selected to insert placeholder text you can type over.

| Button | Inserts | Shortcut |
|--------|---------|----------|
| **Bold** | `**bold text**` | ⌘-B / Ctrl-B |
| **Italic** | `*italic text*` | ⌘-I / Ctrl-I |
| **Heading** | `### ` at the start of the line | |
| **Link** | `[link text](https://)`, with `https://` selected so you can paste the address | ⌘-K / Ctrl-K |
| **Bulleted list** | `- ` at the start of each selected line | |
| **Numbered list** | `1. `, `2. `, ... at the start of each selected line | |

Undo (⌘-Z / Ctrl-Z) reverses a toolbar change like any other edit.

!!! tip "Existing HTML still works"
    Older text often contains HTML tags such as `<b>` or `<i>`. They keep working: the editor never rewrites what is already in a field, and the preview shows the tags as they will appear.

## Web Preview and Email Preview

The header tells you where the text ends up:

- **Preview**: the text is shown on the website, and the preview uses the website's formatting.
- **Email preview**: the text is only sent in emails, and the preview uses the formatting that email uses.

Email-only fields also have a **Send sample email** button at the right of the header. It mails you the real email built from the form as it stands, unsaved edits included, and saves nothing. See [Sample Email Preview](../advanced/email-templates.md#sample-email-preview) for the full list.
