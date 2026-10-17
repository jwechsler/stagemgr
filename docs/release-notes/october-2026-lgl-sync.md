Hi all,

This one is donor focused on automatically synchronizing information from Little Green Light (our donor tracking software). Until now a donor existed twice: once in Stagemgr when they bought a ticket or gave at checkout, and again in LGL when we would import the donation file monthly. Starting in this release the two systems talk to each other, so a donation taken at the box office is a gift in LGL within the hour, and the giving levels LGL works out come back to the customer page every night without anyone exporting a spreadsheet. Alongside it: the Pace projection has moved to where it's actually useful. A bug that stopped us processing the big imported holds is already fixed on the live site as of Saturday night.

---

## Stagemgr and Little Green Light now know each other

**Why:** every gift was synchronized via reports back and forth. This meant that knowing when a customer was a donor could take up to a month. Sad!  

**Now:** each customer who donates gets an **LGL ID** tag, which is LGL's number for them; LGL gets our customer number as its External constituent ID. Once linked, one rule covers everything: **each system owns what it collects, and nothing is ever deleted in LGL.** Concretely:

- **Donations become gifts.** About ten minutes after a donation is processed, the donor is linked (an existing constituent with the same email and last name is adopted; otherwise one is created) and the gift lands in LGL with the amount, date, payment type and a note naming the order. Refunding a donation doesn't delete the gift; it adds a note to it and flags the order for you to sort out in LGL. Only Theater Wit's own donations go across; a visiting company's donation stays where it is.
- **Contact details flow both ways.** Edit a linked customer's name, street or phone here and LGL's preferred address and phone follow a couple of minutes later. Edit them in LGL and Stagemgr picks it up on the next three-hourly poll. Only the *preferred* entries move; LGL's other addresses are left alone.
- **New constituents become customers.** Someone added in LGL who isn't in Stagemgr gets a customer record here, so they'll be matched the first time they buy a ticket.
- **Merges follow.** Merge two customers in Stagemgr and LGL is told; merge two constituents in LGL and, if they look like the same person here, we merge them too. If they don't, you'll see an **LGL Review** tag on the LGL Sync page instead of a silent guess.

**The LGL Review tag** is the one thing that asks something of you. When the sync can't tell which of two records is right (two constituents share an email, a merged customer was linked to two different constituents, that sort of thing), it tags the customer with a one-line reason and stops. Options > System Config > **LGL Sync** lists every customer waiting on a decision, and the manual's LGL page has a table of what each reason means and what to do. Most end with "merge them, then click **Re-sync with LGL**".

**Lapsed donors.** Every linked customer carries an **LGL Lapsed** tag of `LYBUNT` (gave last fiscal year, not yet this one) or `SYBUNT` (gave some year, not last year or this), refreshed early Sunday morning from their LGL gift history. It's a tag, so it works as a filter on the Customers page like any other.

The whole thing runs in the background. The Sync Status page shows when it last polled, what's waiting on review, and has buttons to poll or sweep right now if you've just changed something in LGL and don't want to wait.

Full write-up: manual > Customers > Little Green Light Sync.

---

## Donor tiers come straight from LGL

**Before:** the donor levels import was a spreadsheet someone exported from LGL and uploaded by hand, so it was only as current as the last time anyone remembered.

**Now:** Stagemgr downloads LGL's saved donor-tier report itself every morning at 5:30 and imports it. The customer page shows the tier for this fiscal year and last, the House Management report carries it, and [name] gets an email each morning listing anything that didn't match (usually a constituent whose External constituent ID in LGL is wrong, which is fixed in LGL, not here). The manual upload on the Imports page still works for a one-off.

---

## Expected, not Pace

The projection I added to the production page last release has moved and been renamed. It's now the **Expected** column on Upcoming House Counts and a line on the HUD: the paid count we'd expect at curtain if this show sells the way this house usually does, worked out fresh every night and whenever a house count recalculates. It already includes what's sold; holds and comps aren't in it. Same caveat as before: it's typical behaviour, not a forecast.

---

## What theater users see on a customer

Visiting companies' users now see a narrower customer record: a member shows as **Member [Membership Name]** rather than the member code, the Active Memberships box and donor-tier labels are gone, and Productions Attended lists only their own shows. Box office and admin views are unchanged. Donor levels, which are specific to Theater Wit are also hidden.  This is meant to prevent data leakage between visiting companies.

---

## Imported holds that wouldn't process (already live)

Josh] went to process the 19-seat designer hold for *Mud* (the 2:30 on October 18th) and got "only 27 reservations remaining", which was both true and beside the point: the hold's own seats were being counted twice, so the system thought it needed 38. Every order the summer CSV imports created had the same shape, and 230 of them were still open. The fix went straight to the live site; the stuck orders have been straightened out in place, so if you hit this last week on a different hold, try it again.

---

Jeremy
