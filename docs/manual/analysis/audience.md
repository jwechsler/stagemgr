# Audience Analysis

!!! info "Access"
    Audience Analysis is available to **Admin** and **Theater** users. Theater users
    see only productions belonging to their theaters.

**Navigation:** Admin Menu > Analysis > select "Audience" as the Analysis Type

---

## What it answers

For a selected production, Audience Analysis answers questions about the people who
attended it:

- How many of them are **new** to your programming (no other attendance in a given lookback)?
- How many came back from **the prior show(s)** in a comparison group you choose?
- How many are **repeat patrons** of that comparison group (2+ or 3+ visits)?
- How many have attended **every** comparison-group production whose run overlapped a window?
- How do those same numbers look when you widen the lens from "this company" to
  "the entire facility"?

The output is a single table organized by lookback window (3 months / 6 months / 1 year
/ 3 years / 5 years / **Ever**), with rows broken out by metric, and grouped by
comparison scope. The "Ever" column has no lookback bound — it considers every prior
production that ran up to the anchor date, so it's the closest thing to a true
lifetime-new-vs-lifetime-returning view.

## Picking the comparison group

The Audience type replaces the "Comparison Shows" picker (used by Rate of Sales) with
a **Comparison Group** picker that selects **theaters**, not individual productions:

- **Theater autocomplete** -- Search by theater name or by any
  [tag](../setup/theaters.md#tags) applied to a theater. The current production's theater
  is added automatically as a seed when you switch to Audience.
- **"All theaters tagged X" group entries** -- When the autocomplete finds a matching tag,
  it offers a one-click bulk add of every theater carrying that tag.

You can pick any combination of theaters; at least one is required. The facility-wide
metrics (every theater in the system) are always shown alongside the comparison-group
metrics, so there's no separate toggle for "compare against the whole building" -- those
numbers appear in the lower section of every audience report.

## Anchor date

All windows look **backward from an anchor date**:

- **Closed productions** -- The anchor is the production's closing date. Windows look
  back from there. Orders for shows that ran AFTER the production closed are excluded.
- **Still-running productions** -- The anchor is today. The same post-anchor exclusion
  applies: anything dated after today doesn't count.

This means a customer who attended The Ally and then returned four times after it
closed shows up as a **first-timer** for The Ally's analysis -- but a returning
customer when you run the analysis on the LATER shows. Each analysis is anchored
relative to its own production.

## The metric table

### Header rows

- **Selected production attendees** -- The cohort being analyzed. This is the count of
  distinct Address records linked to paid (non-comp) `Processed` or `Fulfilled`
  TicketOrders on the production. The system already merges duplicate Address records,
  so each address_id represents one real person. Addresses are included if they have
  either an email or a street address (line + zip); addresses with neither are dropped
  because they can't represent a real person, and addresses flagged "Not a ticket buyer"
  are excluded. The cohort itself is comp-filtered (comp recipients of the selected show
  are NOT counted as audience members); cross-attendance to other shows counts both
  paid and comp tickets.
- **Returning attendees ([Production])** -- One row each for the three most recent
  comparison-group productions whose run ended before the selected production opened,
  named with the production. The count is how many cohort members attended that prior
  production at any point in history.
- **Returning attendees (any production)** -- How many cohort members attended any
  production in the comparison group, ever.

These rows have a single value (not broken out by window) because they're lifetime
counts -- "did this person ever attend X".

### Per-window rows

Under the "VS. [Comparison Group Names]" subheader and the "VS. FACILITY" subheader,
each metric is shown across all five windows:

- **Other productions** -- The number of distinct OTHER productions whose run overlapped
  the window in the scope (comparison group or facility). This is the **ceiling** for the
  visit-count metrics: if only 1 production ran, the maximum visit-count is 1.
- **First Time (by recent months)** -- Cohort members with zero attendance to other
  productions in the scope whose runs overlapped the window. Wider windows generally yield
  fewer first-timers (more prior visits get discovered).
- **Dedicated customers** -- Cohort members who attended **every** comparison-group
  production whose run overlapped the window. Zero by definition when no productions ran.
- **2+ visits in comparison** / **3+ visits in building** -- Cohort members who attended
  that many or more distinct productions in the scope whose runs overlapped the window.
  The narrower comparison-group threshold (2+) reflects how few productions usually run
  in a single company's slate, while the broader facility scope uses 3+.

Cells with value 0 are rendered as blank for readability.

## What counts as a "visit"

A visit is a distinct **production** attendance, not a per-performance count:

- Buying two tickets to the same performance of a show = 1 visit
- Buying tickets to two different performances of the same show = 1 visit
- Buying tickets to two different shows = 2 visits

A production is considered "in" a window if its run (first to last performance date)
**overlaps** the window -- not if the customer's specific order date fell inside the
window. This avoids edge cases where a production that ran across a window boundary
was undercounted (e.g., a show that opened just before the 1-year mark and closed just
after).

## What's excluded

- Addresses with neither an email nor a street address (line + zip) -- they can't
  represent a real person.
- Addresses flagged "Not a ticket buyer" in the address record (placeholder records).
- Comp-only orders to the selected production -- people in the cohort had to buy at
  least one paid ticket. (Comp recipients to OTHER shows still count as having attended
  those shows.)
- Orders whose performance date is after the anchor date -- "ignore orders to other
  shows AFTER this date".
- Productions on `Presale` status are not eligible as the selected production but are
  not filtered out of cross-attendance.

## Reading the numbers

Two important sanity checks:

1. **Wider window = fewer first-timers, more repeat-visitors.** This is the expected
   direction. A 3-year window finds more prior attendance per person than 3 months, so
   "First Time" shrinks and "3+ visits" grows as you read left-to-right.
2. **"Dedicated customers" is bounded by "Other productions".** If only 1 production
   ran in the comparison group in 6 months, "Dedicated" = the count of cohort members
   who attended that 1 production. If 5 ran, only patrons who saw all 5 qualify.

If "Dedicated customers" is unexpectedly 0, check the "Other productions" row in the
same column -- often the comparison group simply didn't run enough shows in that window
for the bar to be meaningful.

## Tips

- Use the **default comparison group** (the production's own theater) when asking
  questions about how a specific company is retaining its audience.
- Add additional theaters when asking questions about a coproducing relationship or a
  shared lane of programming (e.g., all musicals, all theaters tagged "Storefront").
- The "VS. FACILITY" section is always shown, regardless of which theaters you pick --
  use it to answer "how many Ally attendees are new to anything we host" as a
  counterpoint to the comparison group's "new specifically to Theater Wit-produced work".
- Tag your theaters meaningfully ([Theater tags](../setup/theaters.md#tags)) so you can
  build comparison groups quickly across recurring partnerships, neighborhood circuits,
  or programming categories.
- The "Returning attendees ([prior production])" rows are the strongest predictor of
  loyalty -- a sizeable number there means your previous show carried over directly
  into ticket sales for this one.

## Future capability

A planned next phase will let you **export the cohort** (and any sub-segment, like
"3+ visits in building") as a CSV for outreach and marketing campaigns. The metric
queries are already cohort-shaped, so the same numbers shown in the table will be
exportable as the actual email list behind them.
