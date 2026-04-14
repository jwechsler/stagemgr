# User Story: Ticket Revenue Analysis

**As a** theater administrator evaluating pricing strategy,
**I want** to compare how ticket sales distributed across price buckets for a current production versus one historical production,
**so that** I can assess whether my pricing decisions (tier structure, dynamic pricing, discount mix) are generating revenue effectively or pushing customers away from higher-priced tiers.

## Scope & Placement

- New analysis tab titled **Ticket Revenue**, sibling to the existing Rate of Sales tab under the analysis feature.
- The **Current Show** selector sits above the tab bar and persists across tab switches.
- This tab has its own **historical production picker** — single-selection, independent of Rate of Sales' multi-select picker.
- A reusable autocomplete endpoint returns production results ranked/matched on **theater name, season, and production name**. Shape it generically so other features can consume it.

## Bucket Model

A **bucket** is a connected component in a production's ticket-class promotion graph, unioned across all of the production's performances.

- Ticket classes linked by promotion triggers (GENA → GENB → GENC, or GENSENIORA → GENSENIORB) form one bucket each.
- Classes with no promotion edges (SUPPORTER, INDUSTRY) are singleton buckets.
- Bucket ranges may overlap and that is acceptable.
- Each bucket exposes a **price range** (min–max of prices actually transacted) and an **average paid price** (demand-weighted, stored at full precision).
- Tickets with `price = 0` and a non-nil `royalty_price` are bucketed by their `royalty_price` and contribute revenue at `royalty_price`.
- **Comps** (zero price, no royalty_price) are segmented out of buckets entirely.
- **Revenue and counts reflect final state, net of refunds.** Exchanged tickets are counted in the bucket of their final ticket class.

## Chart: Two Independent Bar Charts, Side by Side

Each show renders its own vertical bar chart, Y-axis fixed at 0–100%.

- Bars are sorted **descending by average paid price**.
- Denominator toggle:
  - **Capacity mode (default):** Each chart totals 100% of capacity. Paid buckets render as colored bars (descending avg price), followed by a distinct **Comp** bar, followed by a grey **Unsold** bar.
  - **Paid-only mode:** Only paid buckets render; they total 100%. Comp and unsold are suppressed from the bars but remain available in the summary table.
- Each bar is labeled:
  - Primary large label: `$52 avg` (rounded to nearest whole dollar for display only; underlying average kept at full precision for all computations)
  - Secondary smaller label: `$36–$56` (actual price range)
- **Allocation-cap-hit flag** (icon or marker) displays on any bucket whose allocation sold to 100% during the run — distinguishes demand-constrained from supply-constrained outcomes. Only applicable when `TicketClassAllocation#ticket_limit` is set; when nil the flag is never shown (the cap is effectively the house).
- **Hover tooltip** on each bucket bar shows the in-bucket ladder distribution (e.g., "30% sold at $36, 45% at $46, 25% at $56") so the operator can see how far up the dynamic-pricing ladder tickets climbed.

### In-Progress Banner

When the Current Show has not yet closed, display a banner above the chart:

> **Run in progress — X of Y performances complete.** Bucket mix may continue to shift as dynamic pricing lifts engage later in the run.

## Summary Table (below charts, columns side-by-side per show)

- Total paid tickets / Total comp tickets / Total seats available (capacity)
- Capacity utilization % — `(paid + comp) / capacity`
- Gross ticket revenue — cash collected plus royalty-valued amounts for royalty-priced tickets (one combined figure; no separate royalty line)
- Overall weighted average paid price
- **Per bucket** (one row per bucket, ordered to match the chart):
  - Average paid price
  - Bucket sell-through % (paid in bucket / bucket allocation)
  - Actual gross in bucket
  - **Flat-base gross** — counterfactual revenue if every ticket in the bucket sold at the bucket's **entry price** (earliest / first class in the promotion ladder)
  - **Dynamic lift $** — `actual − flat-base` (can be negative if prices triggered downward)
  - **Dynamic lift %**
- Rollup row: overall dynamic lift $ and % across all dynamic buckets

## No Time-Window Crop

This is an aggregate full-run view of each show. No date-of-sale or date-of-performance filter is applied; proportions are regularized via percentage. The in-progress banner is the user's cue to read a mid-run current show's mix with appropriate caution.

## Single-Show Mode (no historical selected)

When no historical production is selected, render the current show's chart and summary table only. The right-hand side (historical chart panel and comparison columns of the summary table) is omitted entirely — no placeholder, no empty state. Dynamic-lift metrics for the current show remain visible.

## Bucket Allocation Denominator

For bucket sell-through %, the denominator is the sum of `TicketClassAllocation#ticket_limit` across all performances for classes in the bucket. When every allocation in the bucket has `ticket_limit = nil`, fall back to `production.capacity * production.performances.count`. When the denominator came from the nil-fallback, the cap-hit flag is not computed (there is no set cap to hit).

## Out of Scope

- Week-by-week rate-of-sale curves (owned by the sibling Rate of Sales tab).
- Multi-show historical comparison (this analysis is strictly 1:1).
- Forcing a shared bucket taxonomy across the two compared shows — buckets are derived independently per production.

## Open for Engineering

- Caching / precomputation strategy for the per-bucket aggregations (ladder distribution, flat-base counterfactual) — likely a summary table or materialized view keyed by production.
- The reusable single-production autocomplete endpoint JSON shape and ranking.
- Handling of productions whose performances have substantially divergent ticket class lineups (union taxonomy should cover this, but worth sanity-testing).
