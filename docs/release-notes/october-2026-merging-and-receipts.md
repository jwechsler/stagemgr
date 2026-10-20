Hi all,

A shorter one this time, and it exists mostly because of what the LGL sync turned up: once Stagemgr and Little Green Light started comparing notes, the LGL Review list filled with pairs of customers that are plainly the same person spelled two ways, and the tool we had for fixing that was a button that merged whatever you'd selected, with no questions asked, and no way to say which address or email should win. So this release is about merging customers properly. Alongside it, the box office receipt now carries a couple of icons so you can tell at a glance who's standing at the window.

---

## Merging customers, with a say in what survives

**Why:** merging was all-or-nothing. **Merge Selected** on the Customers page kept the oldest record and threw the rest away on the spot, and the merge button on the LGL Review list did the same thing from a pop-up. If the newer record had the current street address, tough.

**Now:** both routes open a **Merge customers** page that shows the selected records side by side. One rule covers all of it: **the original record (the lowest customer number) is always the one that survives, and what you choose is which values it ends up with.** Name, street address, email, phone and LGL constituent each get a choice, but only where the records actually differ; where they agree, or only one record has a value, there's nothing to decide and the page says so. The address moves as a unit, so you can't end up with one record's street and another's ZIP. Each choice starts on the newest record that has a value, which is right most of the time, and a sentence at the bottom spells out what's about to happen before you click **Merge into #id**.

If the records have different first names, the page warns you: that's often a couple sharing an email, not a duplicate. Don't merge those; the LGL page in the manual says what to do instead.

Merge Selected still takes two to four rows from the Customers page. It just asks now.

---

## The LGL Review list tells you what it saw

The review list on Options > System Config > **LGL Sync** used to give you the reason and a customer number and leave the rest to you. Each row now shows every customer it matched, the email it matched on, the constituent in LGL, and a short verdict ("Same first name, 2 emails" / "Different first names (Glen, Beth), 2 emails"). Every LGL constituent number, there and in the yellow tag on the customer page, is a link that opens that constituent in LGL in a new window, so sorting out a review is one click to look and one click to **Merge**.

One review that used to stick around now clears itself. When you merge two customers here that were linked to two different constituents, we ask you to merge the pair in LGL as well. Once you have, and LGL kept the one we're tagged with, the tag goes away on its own at the next nightly check, or straight away if you click **Re-sync with LGL**. Before this it stayed until someone removed it by hand, which nobody did, which is how I noticed.

Full write-ups: manual > Customers > Merging Duplicate Patrons, and the LGL Review table on the Little Green Light Sync page.

---

## Icons on the receipt

Up to three small icons now print on the box office receipt, just right of the RECEIPT banner, and only on the receipt, never on the tickets themselves:

- **Star:** the customer is marked VIP.
- **Heart:** the customer is a donor, by LGL's reckoning, this fiscal year or last. The lowest tier doesn't earn one.
- **Check mark:** the order has notes. Read them before you hand the tickets over.

A reprint uses whatever is true at the time of the reprint, so an icon can appear or disappear between the first print and a later one. Legend is in the manual under House Management > Printing Tickets.

---

Jeremy
