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
| An administrator clicks **Link to LGL** / **Re-sync with LGL** on the customer page | The same linking, run in the background straight away |
| The name, street address or phone of a linked customer is edited | About two minutes after the last edit, the new values replace the constituent's **preferred** street address and phone in LGL. Other addresses and phones are left alone; if there is no preferred one, a preferred Home entry is added |

Stagemgr never sends **email** changes to LGL; email addresses in LGL are
managed in LGL. Stagemgr never deletes anything in LGL.

---

## How LGL Merges Reach Stagemgr

Every 15 minutes Stagemgr reads the constituents changed in LGL. When two
constituents have been merged in LGL and both were linked to Stagemgr
customers, Stagemgr merges those two customers as well, provided they look like
the same person (same name or same email). The customer with the **lowest id**
is kept, exactly as in [Merging Duplicates](merging-duplicates.md), and the
surviving LGL constituent is pointed at it.

Each night Stagemgr also checks that every `LGL ID` still exists in LGL. A
customer whose constituent was deleted or merged away is re-linked by customer
id and email, or gets a new constituent if nothing matches.

---

## The LGL Review Tag

When Stagemgr cannot decide safely, it does not guess. It adds an `LGL Review`
tag to the customer whose value says why, for example:

- `2 LGL constituents share this email` -- several constituents could be this
  customer.
- `Also LGL constituent 1234: merge the two in LGL` -- two Stagemgr customers
  linked to different constituents were merged in Stagemgr.
- `LGL constituent 1234 is also linked to #5678` -- LGL merged two
  constituents whose Stagemgr customers do not look like the same person.

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
- How far the 15-minute poll has read LGL's changes, and when the nightly sweep
  last finished ("never" if it has not run).
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
