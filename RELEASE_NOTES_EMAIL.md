# What's new in Stagemgr — May 2026 update

A handful of new features and fixes rolled out over the past week.

## New: Audience Analysis

A new way to understand who's coming to a show, available from the **Analysis** menu and from a new **Audience Analysis** button on each production's page.

Pick a target production and one or more comparison theaters, and the report tells you for each time window (3 months, 6 months, 1 year, 3 years, 5 years, ever):

- **First-time attendees** — patrons whose first visit to your group was this production.
- **Returning attendees** — how many came back after attending a previous show. Headline rows call out the three most recent prior productions specifically.
- **Dedicated attendees** — patrons who attended *every* overlapping production at the comparison theaters during that window.
- **2+ in comparison group** and **3+ in building** — repeat-visit cohorts at different scales.

The report counts a patron toward a window based on when each show *ran*, not when they bought their ticket, so shows that straddled a window boundary are credited correctly.

### Exporting any cohort to TRG Arts

Every count in the results table is **clickable**. Clicking it queues a TRG-format CSV export of that exact cohort and emails it to you when ready (it also lands on the Reports page). The dialog confirms which cohort you're exporting, in plain English.

A few things to know:

- The exports use your TRG patron IDs when available.
- An **OptedInForEmail** column shows Y/N based on the patron's email list opt-in status.
- Emails are only included for patrons who've opted in to your MyEmma list, or if you have email-export permission.
- "vs. facility" cohorts (the wider building-level rows) are admin-only.
- If a count equals the whole cohort, it's shown without a link — exporting it would just give you the cohort itself.

### Convenience touches

- Use the back button after running a report and your comparison theaters stay selected — no need to re-pick them.
- Going from a production's page to Audience Analysis pre-fills the production and seeds its own theater as the comparison group.

## New: Theater tags

You can now tag theaters from the theater edit page — typing brings up existing tags, Enter or comma adds them, and an X removes them. Tags show up next to theater names on the admin theaters list and on each theater's detail page. The theaters search now matches tag names too.

Tags plug into Analysis: the rate-of-sales autocomplete now offers **"All shows tagged X"** group entries, making it easy to roll up performance across thematically related productions.

## Fixes

- **Date pickers look like date pickers again.** The calendar dropdown on report and admin pages was rendering as a wall of plain text. It's back to a proper styled calendar with a header bar, prev/next buttons, and highlighted today/selected dates.
- **Donation List export includes donor emails.** The Email column was coming out blank for every donor — defeating the whole point of the export for fundraising follow-up. Fixed.

## Behind the scenes

- Internal MyEmma library upgraded; a new read-only mode lets developers safely test against real Emma data without risk of writes.
- A Rails startup issue introduced by the above upgrade was resolved.
- Cucumber test reliability improved by sweeping leftover Firefox processes between runs — restoring 46 cascade-failing tests.

---

If you run into any issues with the new audience analysis flow or notice anything that doesn't behave as you'd expect, let us know.
