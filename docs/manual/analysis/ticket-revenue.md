# Ticket Revenue Analysis

!!! info "Access"
    Available to Admin and Theater users. Theater users see only their own productions.

**Navigation:** Analysis > Select show > Run Analysis (Ticket Revenue)

---

## What It Shows

Ticket Revenue analysis answers the question: *"How are tickets distributed across price
points, and how does our pricing strategy affect total revenue?"*

![Ticket Revenue comparison results](../assets/images/screenshots/ticket-revenue-results-comparison.png)

Rather than tracking when tickets were sold, Ticket Revenue focuses on the final state of
the run -- what did tickets actually sell for, and how much revenue did each price tier
contribute? You can analyze a single show or compare it side-by-side with one historical
production.

The analysis page has four sections:

1. [Price Distribution Charts](#price-distribution-charts)
2. [Revenue Summary](#revenue-summary)
3. [Per-Bucket Detail Table](#per-bucket-detail-table)
4. [Dynamic Pricing Lift](#dynamic-pricing-lift)

---

## Setting Up the Analysis

Ticket Revenue is selected from the **Analysis Type** dropdown on the Analysis selection
page. Unlike Rate of Sales, a historical comparison production is **optional** -- you can
run the analysis on a single show without selecting a comparison.

![Analysis selection with Ticket Revenue type and shows selected](../assets/images/screenshots/ticket-revenue-analysis-selection-with-comparison.png)

**Current Show** -- The production you want to analyze. Required.

**Historical Production** -- A single historical production to compare against. Optional.
When selected, charts and tables appear side-by-side for both shows.

Selecting the analysis type changes the comparison field from the multi-show table (used
for Rate of Sales) to a single-production search.

!!! tip "Single-show mode"
    Running the analysis without a comparison production is useful when you want to
    evaluate your current show's pricing distribution on its own -- for example, to
    understand how much revenue is coming from discounted tiers vs full price.

---

## Price Distribution Charts

![Chart showing pricing buckets as bars](../assets/images/screenshots/ticket-revenue-results-chart.png)

Each chart shows one bar per **price bucket** -- a grouping of related ticket classes.
Bar height represents what percentage of tickets (relative to total capacity or total paid
sales) fell into that price tier.

Two additional bars always appear at the right:

- **Comp** -- Complimentary tickets as a share of capacity. Comp revenue is excluded from
  gross revenue calculations.
- **Unsold** -- Seats that were neither sold nor comped (available in capacity mode only).

### Toggle: % of Capacity vs % of Paid Sales

The **% of Capacity** / **% of Paid Sales** buttons control the denominator used for bar
heights and apply to both charts simultaneously.

| Mode | Denominator | What it shows |
|------|-------------|---------------|
| **% of Capacity** | Total seats × performances | How each bucket contributed to filling the house |
| **% of Paid Sales** | Total paid tickets sold | The pricing mix among revenue-generating tickets only |

Capacity mode is the default. It shows the full picture including unsold inventory. Paid
Sales mode is useful for understanding what pricing tiers patrons who actually bought
tickets chose.

### Allocation Cap Flag

A **⚑** flag on a bucket label indicates that the bucket **sold to its allocation limit**
-- every ticket allocated to that price tier was sold. This is a signal that demand at
that price point exceeded supply; more tickets could likely have been sold at that price.

### In-Progress Shows

When a production is still running, a warning banner appears below the chart:

> **Run in progress** -- N of M performances complete.

This reminds you that the revenue picture is incomplete. Either show can be in progress,
and each banner appears independently under its own chart.

### How to Read the Chart

- **Tall bars at high price points** -- Strong uptake at premium prices. If those bars
  also have ⚑ flags, you may have underpriced or under-allocated that tier.
- **Tall bars at discounted prices** -- A significant share of revenue came from
  discounted tickets. Compare to your comparison show to see if this pattern differs.
- **Large Unsold bar** -- Low overall capacity utilization. Combined with small bars at
  higher price points, this may suggest pricing was too high for the demand level.
- **Comp bar size** -- How generous complimentary ticketing was relative to capacity.
  Comps are not revenue, so a very large comp bar reduces effective gross revenue.

---

## Revenue Summary

Scroll below the charts to see a summary table comparing both shows side-by-side.

![Revenue Summary table](../assets/images/screenshots/ticket-revenue-results-summary-table.png)

| Row | Description |
|-----|-------------|
| **Performances** | Total number of scheduled performances |
| **Paid tickets sold** | Total tickets sold through paid orders (excludes comps) |
| **Comp tickets** | Total complimentary tickets issued |
| **Total seats (capacity × perfs)** | Venue capacity multiplied by number of performances -- total available seat-slots |
| **Capacity utilization** | (Paid + Comp) ÷ Total seats, as a percentage |
| **Gross revenue** | Total actual revenue from paid ticket sales |
| **Overall avg paid price** | Gross revenue ÷ paid tickets sold |

---

## Per-Bucket Detail Table

Below the summary, a separate detail table is rendered for each show, listing every
price bucket with full metrics.

| Column | Description |
|--------|-------------|
| **Bucket** | Average paid price (rounded to nearest dollar), ticket class code label, and ⚑ flag if allocation limit was reached |
| **Tickets** | Total paid tickets sold in this bucket |
| **% of Capacity** | Bucket tickets ÷ total capacity |
| **% of Sold** | Bucket tickets ÷ total paid tickets sold |
| **Sell-through** | Bucket tickets ÷ bucket allocation. Reflects how much of the allocated inventory was used |
| **Actual Gross** | Total revenue from this bucket at the prices actually charged |
| **Flat-base Gross** | *(Dynamic buckets only)* -- What gross would have been if all tickets sold at the entry (base) price |
| **Dynamic Lift $** | *(Dynamic buckets only)* -- Actual Gross minus Flat-base Gross |
| **Dynamic Lift %** | *(Dynamic buckets only)* -- Lift as a percentage of Flat-base Gross |

The **Comp** row at the bottom of each table shows how many complimentary tickets were
issued, their share of capacity and paid sales, and notes that they are excluded from
revenue.

### Bucket Labels

The bucket subtitle shown in parentheses below the average price is derived from the
ticket class codes in that bucket:

- If all class codes share a common prefix (e.g., `GEN35`, `GEN40`, `GEN44` → **GEN**),
  the shared prefix is shown.
- If there is no common prefix, the price range is shown instead (e.g., **$17--$20**).

---

## Dynamic Pricing Lift

When any bucket contains multiple linked ticket classes (indicating that Stagemgr's
dynamic pricing shifted some tickets from one class to another during the run), additional
columns appear in the bucket detail table and a **Dynamic Pricing Lift (aggregate)**
rollup table appears at the bottom of the page.

![Dynamic Pricing Lift aggregate table](../assets/images/screenshots/ticket-revenue-results-dynamic-lift.png)

### How Dynamic Buckets Work

Dynamic pricing in Stagemgr works by defining **promotion triggers**: when a ticket
class's allocation fills past a threshold, available inventory shifts to a higher-priced
class. Ticket Revenue Analysis traces these promotion links and groups connected classes
into a single bucket.

For a dynamic bucket:

- **Entry price** is the lowest price in the promotion chain (the "base" price before
  any upselling)
- **Flat-base Gross** is what revenue would have been if every ticket sold at the entry
  price
- **Dynamic Lift $** is the additional revenue earned because some tickets sold at higher
  promoted prices
- **Dynamic Lift %** is the lift as a fraction of the flat-base

### Aggregate Lift Table

| Row | Description |
|-----|-------------|
| **Total lift** | Sum of Dynamic Lift $ across all dynamic buckets |
| **Lift %** | Total lift ÷ total flat-base gross across dynamic buckets |

A positive lift percentage means dynamic pricing generated more revenue than a flat
pricing strategy would have. A zero lift means all tickets sold at the entry price even
though promotion triggers were configured.

!!! tip "Using Lift to Tune Dynamic Pricing"
    If lift is very low (near 0%), check whether promotion triggers are set too
    aggressively (thresholds never reached) or too conservatively (shifted too late in the
    run to affect many tickets). If lift is high and ⚑ flags appear on the promoted
    buckets, consider whether your allocation limits are leaving revenue on the table.

---

## Price Buckets Explained

Buckets are determined automatically from the production's ticket class configuration.
Two ticket classes end up in the same bucket if they are connected by a **dynamic pricing
promotion link** -- meaning one class can shift available inventory to the other.

- **Single-class buckets** -- Standalone ticket classes with no promotion links. The
  dynamic lift columns show `—` for these buckets.
- **Multi-class (dynamic) buckets** -- Two or more classes linked by promotion triggers.
  These show Flat-base Gross, Dynamic Lift $, and Dynamic Lift % columns.

After bucketing, buckets with the same average paid price (rounded to the nearest dollar)
are merged into a single row. This prevents clutter from multiple ticket classes that
happened to sell at identical effective prices.

!!! note "Revenue includes royalty-priced tickets"
    Some ticket classes have a list price of $0 but a non-zero royalty amount. These
    tickets are treated as revenue at the royalty amount for purposes of bucket assignment
    and gross revenue calculation.

!!! note "Refunded tickets excluded"
    Revenue figures reflect the final settled state of all orders. Tickets from refunded
    or canceled orders are not counted. Exchange orders are counted in the replacement
    ticket's bucket.
