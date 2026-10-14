# Merging Duplicate Patrons

!!! info "Role: Administrators Only"
    Merging duplicate patron records is a permanent, irreversible operation restricted to administrators. Use caution and verify selections before confirming a merge.

**Navigation:** Admin > Addresses > Merge Selected

---

## When Duplicates Arise

Duplicate patron records are created when:

- A patron purchases tickets using a different name variation (e.g., "Bob Smith" vs. "Robert Smith").
- Online purchases create a new record because the email or name does not exactly match an existing entry.
- Box office staff create a new record without checking for an existing one.
- A patron uses different email addresses for separate purchases.
- Group orders or will-call entries generate placeholder records that overlap with real patron records.

!!! tip
    Regularly reviewing patron records for duplicates helps maintain clean data. Look for patrons with the same email address, similar names, or identical phone numbers.

---

## How to Merge Duplicates

![Customer list with Merge Selected button for combining duplicate patron records](../assets/images/screenshots/customers-list.png)

1. Navigate to **Admin > Addresses**.
2. Search for the patron whose duplicates you want to consolidate.
3. Identify all duplicate records in the search results.
4. Select the checkbox next to each duplicate record.
5. Click **Merge Selected**.
6. Confirm the merge operation.

---

## Original and Newer Records

A merge always keeps the **original** record, the one with the **lowest ID**
(the one created first), and folds each **newer** record into it. The newer
record is then deleted.

The original record is kept because it usually carries the most history:
past orders, memberships and attendance. Folding the newer record in moves
only its smaller amount of activity, such as a recent order, onto the
patron's established record.

The newer record's details are treated as the most current, so they update
the original wherever the newer record has a value.

---

## Merge Rules

| What | Result |
|------|--------|
| Which record is kept | The original record (lowest ID). Newer records are deleted after the merge |
| Name, email, street address, city, state, ZIP, phone | Each field the newer record has filled in replaces the original's value. A field left blank on the newer record keeps the original's value |
| Tags for different theaters | Kept side by side. Two tags with the same label, such as `External ID`, both end up on the original record when each belongs to a different theater |
| Tags with the same label for the same theater | The newer record's value replaces the original's. Only one tag remains |
| Tags only on the newer record | Moved to the original record |
| VIP and placeholder flags | Set on the original if either record had them |
| Donor levels | The newer record's donor level, when it has one |
| Photo | Copied from the newer record only if the original has none |
| Orders, including gifts the patron received | Moved to the original record |
| Memberships and flex passes | Moved to the original record |
| Payments, pledges and donation history | Moved to the original record |
| Productions attended | Combined on the original record |

!!! warning
    The merge operation is **permanent and cannot be undone**. The newer records are removed from the system after their data is moved. Always double-check that you have selected the correct records before confirming.

---

## Merging More Than Two Records

When you select three or more records, Stagemgr keeps the one with the lowest
ID and folds the others into it one at a time, from the next-lowest ID to the
highest. Because each newer record's filled-in fields replace the ones before
it, the **newest** record's values win wherever it has them.

Each record is folded in separately. If one of them fails, the records already
folded in stay merged.

---

## Before You Merge

Review the following checklist before performing a merge:

- [ ] Verify that the records truly belong to the same person.
- [ ] Note which record has the lowest ID: it is the original and is kept.
- [ ] Check the newest record's name, email, address and phone. Wherever it has a value, that value will replace the original's.
- [ ] Review tags on all records. A tag on the newer record replaces the original's tag with the same label for the same theater.
- [ ] Confirm you have administrator access.

---

## Handling Contact Information Conflicts

Because the newer record's filled-in details replace the original's, correct
the newer record first whenever the original holds the better value. For
example:

| Scenario | Action |
|----------|--------|
| The newer record has an outdated address and the original's is correct | Clear or correct the address on the newer record before merging |
| The patron's preferred email is on the original record | Change the newer record's email to the preferred one before merging |
| The name is spelled correctly only on the original record | Correct the newer record's name before merging |

!!! tip
    Open both patron records in separate browser tabs to compare their information side by side before initiating the merge.

---

## Common Merge Scenarios

| Scenario | Recommended Approach |
|----------|---------------------|
| Same person, different email addresses | The newer record's email is kept. If the original's email is the preferred one, copy it onto the newer record before merging |
| "Bob" vs. "Robert" with same last name and email | Safe to merge. The newer record's spelling is kept |
| Same name but different addresses | Verify they are the same person (check order history, phone) before merging |
| Placeholder record alongside a real patron record | The merged record keeps the placeholder flag if either record had it. Clear the flag on the patron's record after merging |
| More than two duplicates | Select all duplicates at once. The newest record's details win |

---

## Restrictions

- Only users with **administrator** privileges can perform merges.
- Records associated with finalized orders can be merged (their orders move to the original record), but individual records with finalized orders cannot be deleted outside of the merge process.
