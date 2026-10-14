# Little Green Light Sync

!!! info "Role: Administrators"
    Anyone can see a customer's LGL ID. The **Link to LGL** / **Re-sync with LGL**
    button and the sync status page are for administrators.

When Little Green Light (LGL) sync is configured, Stagemgr keeps each customer
linked to the matching constituent in the default theater's LGL account, so a
donor is one person in both systems.

---

## The LGL ID

A linked customer carries an `LGL ID` tag for the default theater: the
constituent's id in LGL. The customer page shows it on the **LGL** line, linked
to the constituent's page in LGL when the account's web address is configured.
"not linked" means Stagemgr has not yet matched the customer to a constituent.

In the other direction, each linked constituent's **External constituent ID**
in LGL is the Stagemgr customer id.

!!! warning
    Do not edit or delete the `LGL ID` tag by hand. Use the **Re-sync with LGL**
    button instead; Stagemgr finds the right constituent and fixes the tag.

---

## When Stagemgr Writes to LGL

| Event | What happens in LGL |
|---|---|
| A donation is processed | About ten minutes later the donor is linked: an existing constituent with the customer's id, or with the same email and last name, is adopted and its External constituent ID set; otherwise a new constituent is created |
| An administrator clicks **Link to LGL** / **Re-sync with LGL** on the customer page | The same linking, run in the background straight away. This is the only way a customer whose LGL record was deleted or merged away gets a new one |
| The name, street address or phone of a linked customer is edited | About two minutes after the last edit, the new values replace the constituent's **preferred** street address and phone in LGL. Other addresses and phones are left alone; if there is no preferred one, a preferred Home entry is added |

Stagemgr never deletes anything in LGL.

---

## When LGL Changes Reach Stagemgr

When someone edits a linked customer's **name**, **preferred street address**
or **preferred phone** in LGL, the change appears on the Stagemgr customer
within about 15 minutes. Clicking **Re-sync with LGL** brings it over straight
away.

- **The newer change wins.** If the customer was edited in Stagemgr more
  recently than in LGL, Stagemgr keeps its own values and sends them to LGL
  instead.
- Only the **preferred** street address and phone are copied. If the
  constituent has no preferred one, the Stagemgr field is left as it is.
- Only customers whose LGL record carries their Stagemgr customer id as its
  **External constituent ID** are updated this way.

**Email is never synced, in either direction**: email addresses in LGL are
managed in LGL, and Stagemgr's are managed in Stagemgr.

---

## How LGL Merges Reach Stagemgr

Every hour Stagemgr checks that every `LGL ID` still exists in LGL, so an LGL
merge reaches Stagemgr within about an hour. (The 15-minute poll picks up
other LGL changes, but a merge does not mark the constituent LGL kept as
changed.) When two constituents have been merged in LGL and both were linked
to Stagemgr customers, Stagemgr merges those two customers as well, provided they look like
the same person (same name or same email). The newer customer is folded into
the original one (lowest id), exactly as in
[Merging Duplicates](merging-duplicates.md), and the constituent LGL kept is
pointed at the original customer.

The same rule applies when Stagemgr links a customer by email: if that email
is on an LGL constituent already linked to another Stagemgr customer with the
same name, LGL is treating them as one person, so Stagemgr folds the newer
customer into the original and links the original.

In the same hourly check, a customer whose constituent was deleted or merged
away is re-linked by customer id and email. If nothing in LGL matches, Stagemgr does **not** create a new LGL
record on its own: the customer keeps the old `LGL ID` and gets an
`LGL Review` tag. Click **Re-sync with LGL** on the customer page to create a
new LGL record for them.

---

## The LGL Review Tag

When Stagemgr cannot decide safely, it does not guess. It adds an `LGL Review`
tag to the customer whose value says why (`1234` stands for an LGL constituent
id, `#5678` for a Stagemgr customer id):

| Reason | Meaning |
|---|---|
| `2 LGL constituents share this email` | Several constituents could be this customer |
| `2 LGL constituents carry external id 5678` | Several constituents in LGL name this customer as their External constituent ID |
| `Also LGL constituent 1234` | LGL says this customer is constituent 1234, but the customer is already linked to a different one |
| `Also LGL constituent 1234: merge the two in LGL` | Two Stagemgr customers linked to different constituents were merged in Stagemgr |
| `LGL constituent 1234 is also linked to #5678` | LGL merged two constituents whose Stagemgr customers do not look like the same person |
| `2 addresses are tagged LGL constituent 1234` | Several Stagemgr customers carry the same `LGL ID` and LGL does not say which one is right |
| `Same person as #5678 in LGL; merge skipped while an order is in progress` | LGL treats this customer and #5678 as one person, but one of them has an order mid-checkout or mid-exchange, so they were not merged |
| `Same person as #5678 in LGL but not a Stagemgr duplicate; merge skipped` | LGL treats the two as one person, but their names and emails differ in Stagemgr |
| `LGL constituent 1234 no longer exists and no LGL constituent matches; use Re-sync with LGL to create a new one` | The customer's LGL record was deleted or merged away and nothing else in LGL matches. Click **Re-sync with LGL** to create a new LGL record |

The customer page shows the reason under the **LGL** line.

**To clear it:** fix the records in LGL (merge the duplicate constituents, or
correct the External constituent ID), then click **Re-sync with LGL** on the
customer page. A successful link removes the tag. If the reason no longer
applies and nothing needs fixing, delete the `LGL Review` tag as you would any
[patron tag](patron-tags.md).

---

## The Sync Status Page

**Navigation:** Options > System Config > LGL Sync

The page shows:

- Whether LGL sync is configured, and whether this environment may write to LGL.
- How far the 15-minute poll has read LGL's changes, and when the hourly sweep
  last finished ("never" if it has not run). The first poll after LGL sync is
  enabled starts from that moment: changes made in LGL before then are not
  copied into Stagemgr. Until it runs, the page says "not yet".
- How many customers are linked.
- Every customer with an `LGL Review` tag, oldest first, with the reason and a
  link to the customer page. The list shows the oldest 100; the heading gives
  the full count.

Three buttons queue the same jobs that run on their own:

| Button | Does |
|---|---|
| **Poll now** | Reads recent LGL changes now instead of waiting for the next 15-minute run |
| **Sweep now** | Checks every `LGL ID` against LGL now |
| **Backfill** | Links every LGL constituent whose External constituent ID names a Stagemgr customer. Changes only Stagemgr's `LGL ID` and `LGL Review` tags, never LGL. Run once after sync is first set up; running it again is harmless |

The jobs run in the background; reload the page after a few minutes to see the
results.
