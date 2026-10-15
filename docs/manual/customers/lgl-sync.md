# Little Green Light Sync

!!! info "Role: Administrators"
    Anyone can see a customer's LGL ID. The **Re-sync with LGL** button and the
    sync status page are for administrators.

When Little Green Light (LGL) sync is configured, Stagemgr keeps each customer
linked to the matching constituent in the default theater's LGL account, so a
donor is one person in both systems.

---

## The LGL ID

A linked customer carries an `LGL ID` tag for the default theater: the
constituent's id in LGL. The customer page shows it in the tag list, linked to
the constituent's page in LGL when the account's web address is configured,
with the **Re-sync with LGL** button beside it. A customer without the tag has
not yet been matched to a constituent.

In the other direction, each linked constituent's **External constituent ID**
in LGL is the Stagemgr customer id.

!!! warning
    Do not edit or delete the `LGL ID` tag by hand. Use the **Re-sync with LGL**
    button instead; Stagemgr finds the right constituent and fixes the tag.

---

## When Stagemgr Writes to LGL

| Event | What happens in LGL |
|---|---|
| A donation is processed | About ten minutes later the donor is linked: an existing constituent with the customer's id, or with the same email and last name (narrowed by first name when several match), is adopted and its External constituent ID set; otherwise a new constituent is created |
| An administrator clicks **Re-sync with LGL** beside a customer's LGL ID | The same linking, run in the background straight away. This is the only way a customer whose LGL record was deleted or merged away gets a new one |
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

**Email is not kept in sync**: when Stagemgr creates a customer from a new LGL
constituent (below), it copies the constituent's preferred email once. After
that the sync never changes an email in either system: email addresses in LGL
are managed in LGL, and Stagemgr's are managed in Stagemgr.

---

## New LGL Constituents Become Customers

When a constituent is added in LGL without a Stagemgr link (its External
constituent ID is empty or does not name a Stagemgr customer), Stagemgr picks
it up within about 15 minutes:

Customers match the constituent when they have the same email address and
last name and are not already linked to another constituent. When several
match, only those with the constituent's first name count. Only the first word
of the first name is compared, so middle initials ("Robert L.") and a couple's
or spouse's record sharing the email do not confuse it.

- If exactly **one** customer matches (or several do and exactly one has the
  constituent's first name), that customer is linked to it.
- If **no** customer matches, Stagemgr creates a new customer with LGL's name
  and the constituent's preferred email, preferred street address and
  preferred phone.
- If **several** customers have the constituent's first name, they are
  spellings of one person: each of them gets an `LGL Review` tag asking for a
  merge. Other customers sharing the email are left alone.
- If several customers match but **none** has the constituent's first name
  (or the constituent has no first name), none is chosen: each gets an `LGL Review` tag
  (see [The LGL Review Tag](#the-lgl-review-tag)).

A linked or newly created customer gets the `LGL ID` tag, and Stagemgr sets the
constituent's **External constituent ID** in LGL to the customer number.

Stagemgr leaves these constituents alone:

- **Organisations.** Only individuals become customers.
- Constituents with **neither an email nor a street address**.
- Constituents with no name, or with an email address Stagemgr does not
  accept. Correct the record in LGL; the change is picked up on the next poll.

!!! note "Existing constituents"
    Constituents that were already in LGL before this sync was set up are
    brought over by a one-time backfill that the developer runs
    (`rake lgl:replicate`). It is not a button on the Sync Status page.

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
| `2 LGL constituents share this email` | Several constituents with this customer's email and last name could be this customer, and their first names do not settle which one |
| `LGL constituent 1234 matches several customers named Robert Holliday by email: merge them in Stagemgr, then Re-sync` | These customers are spellings of one person. On the Sync Status page this customer's name opens the customer list filtered by their last name: merge them with **Merge Selected** (see [Merging Duplicates](merging-duplicates.md)), then click **Re-sync with LGL** on the one that remains |
| `LGL constituent 1234 matches several customers by email and last name` | A new LGL constituent could be any of these customers and none of them shares its first name, so a person must decide; Stagemgr linked none of them. On the Sync Status page this customer's name opens the customer list filtered by their last name, where the duplicates can be selected and merged with **Merge Selected** (see [Merging Duplicates](merging-duplicates.md)); then click **Re-sync with LGL** on the customer that remains. Merging them on the Customers page removes the tag from the customer that remains; automatic duplicate consolidation does not |
| `2 LGL constituents carry external id 5678` | Several constituents in LGL name this customer as their External constituent ID |
| `Also LGL constituent 1234` | LGL says this customer is constituent 1234, but the customer is already linked to a different one |
| `Also LGL constituent 1234: merge the two in LGL` | Two Stagemgr customers linked to different constituents were merged in Stagemgr |
| `LGL constituent 1234 is also linked to #5678` | LGL merged two constituents whose Stagemgr customers do not look like the same person |
| `2 addresses are tagged LGL constituent 1234` | Several Stagemgr customers carry the same `LGL ID` and LGL does not say which one is right |
| `Same person as #5678 in LGL; merge skipped while an order is in progress` | LGL treats this customer and #5678 as one person, but one of them has an order mid-checkout or mid-exchange, so they were not merged |
| `Same person as #5678 in LGL but not a Stagemgr duplicate; merge skipped` | LGL treats the two as one person, but their names and emails differ in Stagemgr |
| `LGL constituent 1234 no longer exists and no LGL constituent matches; use Re-sync with LGL to create a new one` | The customer's LGL record was deleted or merged away and nothing else in LGL matches. Click **Re-sync with LGL** to create a new LGL record |

The customer page highlights the `LGL Review` tag in yellow in its tag list,
with the reason as the tag's value.

**To clear it:** fix the records in LGL (merge the duplicate constituents, or
correct the External constituent ID), then click **Re-sync with LGL** on the
customer page. A successful link removes the tag. Merging the customer with
its duplicate on the Customers page (**Merge Selected**, or merging from the
customer's page; see [Merging Duplicates](merging-duplicates.md)) also removes
it; automatic duplicate consolidation does not. If the reason no longer
applies and nothing needs fixing, delete the `LGL Review` tag as you would any
[patron tag](patron-tags.md).

---

## Lapsed Donors

Stagemgr reads each linked customer's gifts from LGL and marks lapsed donors
with an `LGL Lapsed` tag in the customer's tag list:

| Value | Meaning |
|---|---|
| `LYBUNT` | "Last year but unfortunately not this": gave last fiscal year, but nothing yet this fiscal year |
| `SYBUNT` | "Some year but unfortunately not this": gave in an earlier fiscal year, but not last year or this year |

A customer who has given this fiscal year, or has never given, has no
`LGL Lapsed` tag; the tag is removed when a lapsed donor gives again.

Only money received counts: LGL gifts of type Gift, Installment, Matching, In
Honor of and In Memory of, with an amount above zero. Pledges, in-kind gifts,
soft credits and other income do not. The fiscal year starts on the 1st of the
month the theater has configured (January unless set otherwise).

The tags are refreshed:

- every Sunday night, for every linked customer (this takes about an hour);
- when a customer is first linked to LGL;
- when an administrator clicks **Re-sync with LGL** on the customer page.

So a gift entered in LGL shows on the tag after the next Sunday night, or
straight away after a **Re-sync with LGL**. Do not edit the `LGL Lapsed` tag
by hand: the next refresh replaces it.

---

## Donations Become LGL Gifts

Stagemgr writes each qualifying donation to LGL as a gift on the donor's
constituent record, so the development team does not re-key it.

### Which Donations, and When

A donation is written when its order reaches Processed and is credited to the
**default theater**. That includes a donation added to a ticket order at
checkout for any show in the building. A donation credited to another company
is not written, and neither is a standalone donation with no theater.

Only donations placed after gift replication went live are written: the moment
the first gift campaign was chosen on the Sync Status page. Earlier donations
stay as entered by hand.

The gift is written about 13 minutes after the order is processed. Ten minutes
after processing the customer's address is synced to LGL (see
[When Stagemgr Writes to LGL](#when-stagemgr-writes-to-lgl)); three minutes
later the gift follows.

- If the customer is not yet linked to an LGL constituent, the gift job waits
  and retries for about 8 hours.
- If the customer carries an `LGL Review` tag, the gift waits until a person
  resolves the review. Once the customer is linked (for example after
  **Re-sync with LGL**), any waiting gifts are written automatically.

### What the Gift Contains

| Field | Value |
|---|---|
| Type | Gift |
| Amount | The donation amount; the received, deductible and deposited amounts all equal it |
| Received date and deposit date | The day the payment was taken |
| Payment type | Credit Card, Cash or Check |
| Note | `Stagemgr donation order #<order number>` |
| External id | `stagemgr-<order number>`, which keeps the same donation from ever being written twice |

**Campaign.** Choose the campaign on the Sync Status page from LGL's active
campaigns (the **Gift campaign** row, with a **Change** link). Until one is
chosen no gifts are written. Changing it affects future gifts only.

**Appeal.** Every gift goes on an appeal named `<season> Ticketing` (for
example `2026 Ticketing`, type Ticketing) under the chosen campaign. Stagemgr
creates the appeal in LGL when it does not exist, and adopts an existing one
with that exact name.

**Event.** Each production is an LGL event with the production's name, dated
from its first performance to its closing date, tied to the campaign and
marked active. Stagemgr creates the event when none exists, adopts an existing
event with the production's exact name, and fills in the campaign, dates and
active flag on an event that lacks them, including re-activating one marked
inactive. The production is known for donations placed since gift replication
began; for older donations Stagemgr matches the production name recorded on the
donation. A donation with no matching production gets a gift with no event.

### Refunds and the Order Page

Refunding a donation in Stagemgr never deletes or zeroes the LGL gift. About a
minute later the gift's note gains the line `Refunded in Stagemgr on <date>`.
Adjust the gift in LGL by hand if needed.

A donation order's page shows **Little Green Light: Gift #<id>** (or "not in
LGL") and a link to the constituent, with a **Send to LGL** button that queues
the gift again. It is safe to press: an existing gift is never duplicated, and
donations from before go-live are never sent.

In a read-only environment nothing is written; the log lines say the write was
skipped.

---

## The Sync Status Page

**Navigation:** Options > System Config > LGL Sync

The page shows:

- The **Sync** row: **Enabled**, **Read-only** or **Disabled**, and whether
  this environment may write to LGL.
    - **Enabled**: changes flow both ways as described on this page.
    - **Read-only**: used for testing. Stagemgr still reads from LGL, links
      customers and creates new customers from LGL constituents, but writes
      nothing to LGL, except for any customers the developer has listed for
      acceptance testing. A development install set to enabled runs
      read-only, and the page says so.
    - **Disabled**: no sync in either direction.
- How far the 15-minute poll has read LGL's changes, and when the hourly sweep
  last finished ("never" if it has not run). The first poll after LGL sync is
  enabled starts from that moment: changes made in LGL before then are not
  copied into Stagemgr. Until it runs, the page says "not yet".
- How many customers are linked.
- **Lapsed donors**: how many customers carry an `LGL Lapsed` tag of each kind
  (see [Lapsed Donors](#lapsed-donors)), and when the weekly gift history
  refresh last finished ("never" if it has not run).
- **Gift campaign**: the campaign gifts go on (name and id, with a **Change**
  link). When none is set the row shows the chooser and the note "Donations are
  not sent to LGL until a campaign is chosen."
- **Donations in LGL**: how many donations have been written as gifts (see
  [Donations Become LGL Gifts](#donations-become-lgl-gifts)).
- **Last gift replicated**: when a gift was last written ("never" if none has).
- Every customer with an `LGL Review` tag, oldest first, with the reason and a
  link to the customer page. When the reason is that several customers match,
  the link goes to the customer list filtered by the customer's last name
  instead, so the duplicates can be merged. The list shows the oldest 100; the heading gives
  the full count.

Four buttons queue the same jobs that run on their own:

| Button | Does |
|---|---|
| **Poll for changes** | Reads recent LGL changes now instead of waiting for the next 15-minute run |
| **Sweep all** | Checks every `LGL ID` against LGL now, not just recent changes |
| **Refresh gift history** | Refreshes every linked customer's `LGL Lapsed` tag now instead of waiting for Sunday night. Asks for confirmation first: it reads each customer's gifts from LGL and takes about an hour |
| **Backfill** | Links every LGL constituent whose External constituent ID names a Stagemgr customer. Changes only Stagemgr's `LGL ID` and `LGL Review` tags, never LGL. Run once after sync is first set up; running it again is harmless |

The jobs run in the background; reload the page after a few minutes to see the
results.

### Donor Tiers

Three more rows report the nightly
[donor levels import](../imports/donor-levels-import.md) from LGL. They appear
whatever the sync mode:

| Row | Shows |
|---|---|
| **Donor-tier report** | **On** when the LGL report link is configured, with the person the import results are emailed to; **Off** otherwise |
| **Last report download** | When Stagemgr last downloaded the report from LGL successfully |
| **Last donor levels import** | When a donor levels import last finished, whether from the nightly download or a manual upload on the Imports page |

When the report is on, a **Fetch donor levels now** button downloads the
report and imports it straight away instead of waiting for the nightly run.
