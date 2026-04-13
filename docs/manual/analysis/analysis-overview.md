# Analysis Overview

!!! info "Access"
    Analysis is available to **Admin** and **Theater** users. Box Office users do not have
    access. Theater users see only productions belonging to their theaters.

**Navigation:** Admin Menu > Analysis

---

## About Analysis

The Analysis section lets you compare a current show's sales performance against a set of
historical productions. Unlike Reports, which export raw data, Analysis provides computed
insights, visual comparisons, and revenue projections to help you make decisions about
marketing spend, run extensions, and programming.

## Analysis Types

### Rate of Sales

Compares week-over-week growth in ticket sales and revenue between a current show and a
set of historical comparison shows. Includes:

- **Daily Average Rate of Sales** -- Rolling 7-day revenue for the current show, plotted
  daily for a high-resolution view of sales momentum
- **Rate of Sales Charts** -- Week-over-week percentage change in tickets and revenue for
  the current show, alongside the historical aggregate average
- **Performance Insights** -- Computed metrics comparing the current show to historical
  averages (tickets/week, revenue/week, growth trajectory, lifecycle position)
- **Revenue Projection** -- Two projected cumulative revenue lines through end of run:
  a **Historical-scaled** line that applies the current show's performance ratio to a
  comparison-show lifecycle curve, and a **Self-scaled (momentum)** line that extends
  the current show's own recent growth rate forward. Both lines are capped by remaining
  seat inventory and support modeling run extensions.

See [Rate of Sales Analysis](rate-of-sales.md) for full details.

![Analysis selection page](../assets/images/screenshots/analysis-selection-empty.png)

## Setting Up an Analysis

Every analysis requires two selections:

1. **Current Show** -- The production you want to analyze. Select one show using the
   autocomplete search field.
2. **Comparison Shows** -- One or more historical productions to aggregate as the baseline.
   You can add shows individually or use bulk shortcuts.

### Searching for Productions

Type at least 2 characters in either search field. You can search by:

- Production name
- Season year (e.g., "2025")
- Production code

Productions on **Presale** status are excluded from search results. All other statuses
(Active, Inactive, Private) are available.

### Bulk Selection Shortcuts

When adding comparison shows, the autocomplete offers group shortcuts at the top of the
results list, shown with a triangle icon:

- **All shows in [year]** -- Adds every production from that season
- **All shows by [company]** -- Adds every production by that theater company

Selecting a group shortcut expands it into individual productions in the comparison table.
You can then remove any shows you don't want included. Theater users only see groups for
their own theaters.

![Autocomplete with group shortcuts](../assets/images/screenshots/analysis-autocomplete-groups.png)

### Managing the Comparison List

Each comparison show appears in a table with Season, Production, and Theater columns.
You can:

- **Remove individual shows** by clicking "remove" on any row
- **Remove all shows** by clicking the "Remove all" button (with confirmation)
- **Return with selections intact** -- The "Back to Analysis" button on the results page
  preserves your current and comparison selections

![Selection page with shows populated](../assets/images/screenshots/analysis-selection-populated.png)

### Running the Analysis

Once you have selected a current show, at least one comparison show, and an analysis type,
click **Run Analysis** to generate results.

## Tips

- For meaningful comparisons, select shows with similar characteristics (venue size,
  genre, audience demographics). A small fringe show compared against a large-venue
  musical will produce skewed ratios.
- Include 3-5 comparison shows when possible. A single comparison show reflects that
  one show's specific trajectory; multiple shows smooth out anomalies.
- Season-based selection ("All shows in 2024") is useful for understanding how this
  year's programming compares to a prior season overall.
- Theater-based selection ("All shows by Theater Wit") is useful for understanding a
  company's historical sales pattern.
