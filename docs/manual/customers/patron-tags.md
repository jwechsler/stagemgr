# Patron Tags

!!! info "Role: Managers, Administrators"
    Patron tags allow you to attach custom key-value metadata to any address record. Tags are scoped by theater, so each venue can maintain its own tagging system independently.

**Navigation:** Admin > Addresses > [Select Patron] > Tags

---

## What Are Patron Tags?

Tags are flexible labels you can attach to patron records to store supplemental information that does not fit into the standard address fields. Each tag consists of three components:

| Component | Description |
|-----------|-------------|
| Tag Label | The name or category of the tag (e.g., "Donor Level", "External ID") |
| Tag Value | The value assigned to the patron for that label (e.g., "Gold", "CRM-48291") |
| Theater | The theater this tag belongs to; tags are scoped per theater |

A patron can have multiple tags, including multiple tags with the same label (e.g., several external IDs from different systems).

---

## Adding Tags to a Patron

1. Navigate to **Admin > Addresses** and find the patron.
2. Open the patron's record.
3. Scroll to the **Tags** section.
4. Enter a **Tag Label** and **Tag Value**.
5. Select the **Theater** the tag applies to.
6. Click **Save**.

!!! tip
    Use consistent naming conventions for tag labels across your staff. For example, always use "Donor Level" rather than mixing "Donor Level", "DonorLevel", and "Donor Tier" for the same concept.

---

## Theater Scoping

Tags are scoped to individual theaters, meaning:

- A tag created under Theater A is only visible and relevant in the context of Theater A.
- The same patron can have different tags for different theaters.
- Staff working with a specific theater will see only the tags relevant to that theater.

This is useful for multi-venue organizations where each theater tracks different patron attributes.

---

## Common Uses for Tags

| Tag Label | Example Values | Purpose |
|-----------|---------------|---------|
| Donor Level | Bronze, Silver, Gold, Platinum | Track giving tiers for house management and VIP treatment |
| External ID | CRM-48291, SF-1042 | Link patron records to external CRM or fundraising systems |
| VIP Designation | Board Member, Press, Artist Guest | Identify special guests beyond the basic VIP flag |
| Seating Preference | Aisle, Front Row, Accessible | Record seating preferences for house management |
| Comp Reason | Reviewer, Staff Family, Sponsor | Document why a patron receives complimentary tickets |
| Communication Pref | No Mail, Email Only | Track patron communication preferences |
| Membership Tier | Individual, Family, Patron Circle | Record membership levels from external membership systems |

---

## Editing and Removing Tags

To edit an existing tag:

1. Open the patron's record.
2. Locate the tag in the Tags section.
3. Modify the **Tag Label** or **Tag Value** as needed.
4. Click **Save**.

To remove a tag, delete the tag entry from the patron's record and save.

---

## Tags vs. VIP Flag

The VIP boolean flag on a patron record is a simple on/off indicator. Tags provide much richer categorization:

| Feature | VIP Flag | Patron Tags |
|---------|----------|-------------|
| Data type | Boolean (yes/no) | Key-value pair (any text) |
| Theater scope | Global across all theaters | Scoped per theater |
| Multiple values | No (single flag) | Yes (unlimited tags) |
| Searchable | Yes (filter by VIP) | Varies by report |
| Use case | Quick VIP identification | Detailed categorization |

!!! warning
    Tags are informational metadata. They do not automatically trigger any system behavior such as discounts, priority seating, or email segmentation. Staff must manually consult tags during house management and patron interactions.

---

## Best Practices

- **Standardize labels**: Agree on a consistent set of tag labels across your team to keep data clean.
- **Review periodically**: Tags like "Donor Level" may need annual updates after fundraising campaigns.
- **Use theater scoping intentionally**: Only scope tags to a specific theater when the information is truly theater-specific. For organization-wide attributes, pick one primary theater or use a consistent convention.
- **Document your tags**: Maintain an internal reference list of approved tag labels and their expected values so all staff use them consistently.
