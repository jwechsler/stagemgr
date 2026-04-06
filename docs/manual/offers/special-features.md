# Special Features

!!! info "Who uses this?"
    **Production Managers** and **Marketing Staff** create special features to tag performances with notable attributes that are displayed to customers on the website and in confirmation emails.

**Navigation:** Admin > Offers > Special Features

---

## Overview

Special features are descriptive tags that can be assigned to individual performances to communicate unique attributes -- such as "ASL Interpreted," "Post-Show Talkback," or "Pay-What-You-Can." When assigned, these features are displayed prominently on the public website calendar and in order confirmation emails.

## Creating a Special Feature

### Fields

| Field | Description |
|-------|-------------|
| **Short Name** | A concise label displayed in listings and email subject lines (e.g., "ASL Interpreted"). Must be unique across all special features. Required. |
| **Description** | A longer explanation of the feature shown on the performance detail page. Supports Markdown formatting for links, bold text, and lists. Required. |
| **Status** | `Active` or `Inactive`. Only active features can be assigned to performances and are visible to customers. |

!!! tip "Use Markdown in descriptions"
    The Description field supports Markdown. Use it to include links to additional information, format text for readability, or add structured details about the feature.

---

## Assigning Features to Performances

Special features are assigned at the **performance level**, not the production level. This allows different performances of the same production to have different features.

To assign features:

1. Navigate to the production's performance list.
2. Edit a specific performance.
3. In the Special Features section, check the boxes next to each feature that applies.
4. Save the performance.

A single performance can have multiple features assigned simultaneously (e.g., both "ASL Interpreted" and "Post-Show Talkback").

!!! tip "Bulk assignment"
    When multiple performances share the same feature, edit each performance individually. There is no bulk assignment tool, so plan feature assignments when scheduling performances.

---

## Where Features Are Displayed

### Public Website

- **Calendar/listing view:** The short name appears as a badge or tag next to the performance date and time.
- **Performance detail page:** The full description is displayed, rendered with Markdown formatting.

### Confirmation Emails

- When a customer purchases tickets for a performance with special features, the **short name** and **description** are included in the order confirmation email so the patron knows about the feature in advance.

!!! warning "Inactive features are hidden everywhere"
    Setting a feature to `Inactive` immediately removes it from the website and from future confirmation emails. It does not remove it from already-sent emails.

---

## Examples of Common Special Features

| Short Name | Description |
|------------|-------------|
| ASL Interpreted | This performance includes American Sign Language interpretation. |
| Audio Described | A live audio description is provided for patrons who are blind or have low vision. |
| Post-Show Talkback | Stay after the show for a Q&A session with the cast and creative team. |
| Pay-What-You-Can | Ticket prices are flexible -- pay what you can afford. |
| Preview Performance | This is a preview performance. The production is still in final rehearsals. |
| Relaxed Performance | A sensory-friendly performance with adjusted lighting and sound levels. |

---

## Managing Special Features

- **Deactivate** a feature by setting its status to `Inactive`. It will no longer appear on the website or in emails, and it cannot be assigned to new performances.
- **Reactivate** by switching back to `Active`. Any performances that still have the feature checked will immediately display it again.
- **Delete** a feature only if it is no longer assigned to any performances. Removing assignments first prevents orphaned references.
