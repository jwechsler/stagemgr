# Changelog

!!! info "Reference"
    Recent feature additions and significant changes to Stagemgr, listed from newest to oldest.

## October 2026

### Refunds for Exchanged Orders

**Available to:** Administrator, Box Office

An order created by an exchange can now be refunded. Refunding the newest order of an exchange
chain returns every payment in the chain on its own tender and reverses the exchange credits,
offsets and Carryovers between the orders.

**Key behaviors:**

- The refund page lists each order in the chain under its own heading.
- The newest order becomes **Refunded** and releases its seats; earlier orders stay **Exchanged**.
- All or nothing: if a card refund fails, nothing is refunded.

See [Refunds](../ticketing/refunds.md#refund-eligibility).

## September 2026

### Add to Order

**Available to:** Administrator, Box Office

An **Add to Order** button on a **Processed** ticket order adds tickets or add-ons -- a guest's
seat, a captioning tablet, a dinner -- to the patron's existing order. The patron keeps their
tickets and seats and pays only for the new items, which join the original order under the same
order number.

**Key behaviors:**

- Any Processed order, whatever the performance date; once an order is Fulfilled the patron needs a new order.
- Same performance only, shown in a banner at the top of the page along with what is already on the order.
- Items sell at face value (no special offer or discount code); per-ticket fees still apply, and the addition may be comped.
- Works for general admission and reserved seating (pick the new seats on the map).
- Notes typed on the addition are added to the original order's notes; one updated confirmation is sent unless you untick it.
- All or nothing: if anything fails, nothing is saved and any card charge is refunded.
- The order's change history records *Added from order #...* with the items and card charge.

See [Add to Order](../ticketing/add-to-order.md).

### Refunds for Orders With Several Payments

**Available to:** Administrator, Box Office

Orders carrying more than one payment -- common after Add to Order -- can now be refunded. The
refund page lists what happens to each payment (card refunded, cash handed back, pass tickets
released, nothing-to-refund payments skipped) under a single button.

**Key behaviors:**

- A card payment already partly refunded returns only what is left on the charge.
- Orders paid with exchange credit were refunded through **Exchange and Refund** instead (see *Refunds for Exchanged Orders*, October 2026).

See [Refunds](../ticketing/refunds.md#orders-with-several-payments).

### Exchange Payment Types and Pass-Plus-Money Orders

**Available to:** Administrator, Box Office

Exchange now offers the payment types the performance allows, with the original order's type
preselected when it is allowed. Orders paid with both a pass (membership or flex pass) and a
money payment can no longer be exchanged or split, because the system cannot tell which seats the
pass paid for.

**Key behaviors:**

- The order page explains why Exchange is missing; refund the order and place a new one instead.
- **Update seating** (Change Seating) still works on these orders.

See [Exchanges](../ticketing/exchanges.md) and [Split Orders](../ticketing/split-orders.md).

### Membership Tickets Per Performance Enforced Across Orders

**Available to:** Administrator, Box Office

A membership's **Tickets Per Performance** limit now counts the seats the membership has paid for
on all of the member's current orders for the performance, not just the order being placed. The
limit had never been checked across orders before.

**Key behaviors:**

- Exchanged, canceled and refunded orders do not count.
- Extra seats paid by card (for example through Add to Order) do not count against the limit.

See [Membership Offers](../offers/membership-offers.md#how-ticket-redemption-works).

### Card Charged Only After Every Check

**Available to:** All staff and online patrons

A card is now charged only after every check on the order has passed, so a failed order no longer
leaves the card charged. If something still fails after the charge, the charge is refunded
automatically. The same applies to exchange price differences and membership purchases.

**Key behaviors:**

- A declined additional donation no longer affects the ticket order: the tickets go through, the patron is told the donation could not be processed, a note is added to the order and the box office is emailed an alert.

See [Payment Processing](../ticketing/payment-processing.md#additional-donations).

### Placed Date in the Orders List

**Available to:** All staff

Each row's **Description** on the Orders list now ends with the date the order was placed, for
example *, placed 09/19*, so you can see when an order was made without opening it.

See [Order Search](../ticketing/order-search.md).

### House Count Ignores Add-Ons That Hold No Seat

**Available to:** All staff

The house count's **Sold** figure now counts only tickets whose class holds a seat, so add-ons such
as a captioning tablet or a dinner no longer use up seats in the house.

See [House Counts](../house-management/house-counts.md).

### Refunded Fulfilled Order Alert Restored

**Available to:** Administrator, Box Office

Refunding an order that was already **Fulfilled** now emails the **Box Office** and **Supervisor
Notifications** addresses again, naming the order and the staff member who refunded it, so the
printed tickets can be destroyed. The alert had not been sent since 2022. Patrons still receive no
refund email. See [Refunds](../ticketing/refunds.md#notification-behavior).

### Formatted Text Editor

**Available to:** Administrator, Box Office

Every Markdown-enabled admin field now shows its text **as patrons will see it**, under a
**Preview (click to edit)** header. Clicking the preview opens a formatting toolbar and the text
box below it, and the preview updates as you type. Email-only fields are headed **Email preview**
and preview with the formatting their email uses.

**Key behaviors:**

- Toolbar buttons for bold, italic, heading, link, bulleted and numbered lists; ⌘/Ctrl-B, -I and -K shortcuts.
- **Done** or **Escape** closes the editor; a field with a validation error opens already expanded.
- Stored text is never rewritten, so existing hand-written HTML keeps working.
- The Email Attendees message body uses the same editor, opened ready to type.
- Membership offer **Email HTML** is now **Confirmation Email Text** and is rendered as Markdown (embedded HTML still works).

See [Formatted Text Fields](../getting-started/formatted-text.md).

### Send Sample Email From Every Email Field

**Available to:** Administrator, Box Office (membership offers: Administrator)

Every email-only text field now has a **Send sample email** button at the right of its
**Email preview** header. It mails you the real email built from the form's unsaved values,
and nothing is saved. The production form's old **Send sample confirmation email** and
**Send sample follow-up email** buttons under the fields are gone; the header button replaces them.

| Field | Email sent |
|-------|------------|
| Production **Additional Confirmation Message** / **Follow-up message** | Ticket confirmation / post-show follow-up, as before |
| Ticket class, default and resourced ticket class **Purchase Email Annotation** | Ticket confirmation carrying the annotation |
| Performance and special feature **Custom Email** | Ticket confirmation with the feature text |
| Membership offer **Confirmation Email Text** | Membership confirmation; no membership is created |
| Email Attendees **Message Body** | The attendee email, to you only; nothing is queued for ticket holders |

**Key behaviors:**

- The header's **Email preview (click to edit)** is now a button that opens and closes the editor from the keyboard; clicking the preview still opens it.
- Sending a sample doesn't open or close the editor.

See [Email Templates](../advanced/email-templates.md#sample-email-preview).

### Propagate Toggle -- Switch Classes Off Down the Run, Reset Dynamic Pricing

**Available to:** Administrator, Box Office

The allocation grid's **⇉** toggle is now always offered on manually managed classes and fans
the row out **as-is, on or off**, so a class can be switched off for the rest of a run in one
save. Propagating onto performances whose dynamic pricing ladder has already advanced no
longer leaves the old and new price tiers on sale together.

| Detail | Description |
|--------|-------------|
| **Deactivation** | An unchecked Available with the toggle armed switches the class off on every subsequent performance, along with any tiers it had shifted to |
| **Reset and replay** | On each later performance the existing ladder from the row is switched off, the new row lands, and that performance's triggers re-run against its own sales and date |
| **Immediate evaluation** | The edited performance resets the ladder of any row re-armed in the form and re-runs its own shift triggers on save instead of waiting for the 1:00 AM sweep |
| **Sweep hardening** | A shift whose target class has no allocation on the performance is logged and skipped instead of aborting the nightly run |

**Key behaviors:**

- Manually enabled tiers downstream of the propagated row are reset like shifted ones; converging ladders share their target, so propagate each head.

See [Performances](../productions/performances.md#propagating-a-row-to-later-performances) and
[Dynamic Pricing](../productions/dynamic-pricing.md#editing-triggers-mid-run).

## August 2026

### Resourced Ticket Classes -- Shared Equipment Pools

**Available to:** Administrator (management); Box Office (selling and per-performance activation)

A new kind of globally managed ticket class backed by a limited pool of physical equipment
shared between venues -- assistive closed-captioning tablets, audio-description receivers,
and similar devices. Each ticket sold claims one device, and Stagemgr enforces the pool
limit across venues and across overlapping performances, so the hardware can never be
double-booked.

| Detail | Description |
|--------|-------------|
| **Where** | Options > Resourced Ticket Classes |
| **Pool settings** | Quantity (devices that exist) and Changeover Minutes (buffer before curtain and after the show ends) |
| **Venue scoping** | Each resource is tied to a set of venues; performances of productions in those venues share -- and count against -- the pool |
| **Occupancy window** | A device is busy from (curtain − changeover) through (curtain + running time + changeover); productions without a Running Time use the `resourced_default_runtime_minutes` server default |
| **Enforcement** | Exhausted pools hide the class from sale, cap quantity dropdowns, and refuse any order that would exceed the pool -- including box office orders. There is no override |
| **Exchanges** | Exchanging a device ticket works even at a full pool -- the released ticket's device carries to the replacement order |
| **Per-production copies** | The class appears on every production in scope, labeled "Global (resourced)" and read-only; price and settings are managed once, globally |
| **Activation** | Allocations are always created inactive; staff enable them per performance (e.g., once the show is teched). There is deliberately no auto-attach |

**Key behaviors:**

- Editing the resource syncs changes to every production copy in the background; the detail page shows a syncing banner and refreshes when done.
- The detail page warns about class code conflicts (a production's own class with the same code is never overwritten) and productions missing a Running Time.
- Removing a venue or deleting a resource with sales *decommissions* the class -- hidden from sale, future allocations switched off, sold history preserved.

**Use cases:** Ten captioning tablets shared by two theaters -- a 2:00 PM show using all ten
blocks an overlapping 3:00 PM show next door from selling an eleventh, while a 7:30 PM show
the same evening sells freely once the devices have turned around.

See [Resourced Ticket Classes](../productions/resourced-ticket-classes.md).

---

### Resource Pull Sheet Report

**Available to:** Administrator, Box Office, House Manager

A per-date report listing every shared-equipment reservation so staff know how many devices
to pull and stage at each venue, and which patrons reserved them.

| Detail | Description |
|--------|-------------|
| **Where** | Admin > Reports > Resource Pull Sheet |
| **Grouping** | One section per resourced ticket class, rows grouped by performance in code order |
| **Sorting** | Patrons sorted by last name, first name within each performance |
| **Totals** | Per-performance subtotal (devices to stage at that venue) and per-resource daily total |
| **Counted orders** | Holds, in-progress checkouts, processed, fulfilled, and mid-exchange orders; refunds are netted out |

See [Resource Pull Sheet](../house-management/resource-pull-sheet.md).

---

### Allocation Grid -- Propagate a Row to Later Performances

**Available to:** Administrator, Box Office

A compact **⇉** toggle in the performance edit form's ticket class allocation grid copies a
row's configuration to the rest of the run in one save, instead of editing each performance
individually.

| Detail | Description |
|--------|-------------|
| **Where** | Performance edit page > Ticket Class Allocations grid, next to the Available checkbox |
| **What propagates** | Availability, Ticket Limit, and the dynamic pricing trigger fields (Trigger?, To Code, At %, Days Before) |
| **Scope** | Every subsequent performance of the production, anchored to the edited performance's date and time -- earlier performances are untouched |
| **When** | Only on a successful save; arming the toggle alone changes nothing |
| **Which classes** | All manually managed classes. Auto-attach classes have no toggle |

**Key behaviors:**

- Propagation overwrites the later allocations' settings so the rest of the run ends up uniform with the edited row.
- Originally it only fanned out an activation; since September 2026 it fans the row out on or off (see above).

**Use cases:** Enable captioning tablets for the remainder of a run the day the show is
teched. Roll a mid-run price-tier change (new limit and shift trigger) forward across the
remaining performances in one save.

See [Performances](../productions/performances.md#propagating-a-row-to-later-performances).

## July 2026

### Production Navigation and Selection

**Available to:** All staff roles (scoped to accessible theaters)

A new **Productions** section in the top menu lists every production you can access across
all theaters, and production selection on the Reports, Imports, and Analysis pages now uses
a shared typeahead search with season/theater/tag drill-down.

| Detail | Description |
|--------|-------------|
| **Where** | Top menu > Productions; Reports, Imports, and Analysis forms |
| **Productions list** | Searchable table of all accessible productions with Name, Theater, Season, Status, and Actions |
| **Search picker** | Replaces production dropdowns; matches name, season, code, or theater; group shortcuts drill down to a single show |
| **Report scope** | Report search now offers all accessible productions, including Inactive and Presale |
| **Import scope** | Import search excludes Inactive productions |
| **Report feedback** | Submitting a report shows a "Report requested" overlay immediately |

See [Finding Productions](../productions/finding-productions.md).

## April 2026

### House Management Report -- Visits Column and Frequent Attendees

**Available to:** Administrator, Box Office, House Manager

The House Management Report now includes a **Visits** column and a new inclusion rule for frequent attendees.

| Detail | Description |
|--------|-------------|
| **Where** | Admin > Reports > House Management Report |
| **Visits column** | Count of the patron's Processed and Fulfilled ticket orders on or before the report date |
| **Frequent attendee rule** | Patron is listed if their visit count meets the configured threshold, even with no other signals |
| **External ID tag** | No longer forces inclusion and is hidden from the Patron Notes column |

**Configured in `server.yml`:**

- `report_frequent_customer_at` -- minimum visits to qualify as a frequent attendee (leave unset to disable)
- `report_frequent_customer_range_days` -- lookback window in days; leave unset to count full history. The same window is applied to the Visits column.

**Use cases:** Identify loyal patrons during check-in who have no VIP flag or donor tag but have attended many shows. Keep the Patron Notes column focused on front-of-house-relevant tags by suppressing the internal External ID marker from imports.

See [House Management Report](../house-management/house-management-report.md).

---

### Ticket Revenue Analysis

**Available to:** Administrator, Theater User

A new analysis type on the Analysis screen that shows how ticket sales distributed across price tiers and how your pricing decisions affected gross revenue. Select it from the Analysis Type dropdown alongside the existing Rate of Sales analysis.

| Detail | Description |
|--------|-------------|
| **Where** | Analysis menu > Analysis Type: Ticket Revenue |
| **Comparison** | Optional -- run on a single show or compare side-by-side with one historical production |
| **Revenue figures** | Net of ticketing fees |

**What it shows:**

- **Price distribution charts** -- One bar per price tier showing what percentage of paid sales came from each bucket. Bars are sorted high-to-low by average price. A ⚑ flag marks any tier that sold to its allocation limit.
- **Revenue summary** -- Performances, paid tickets, comp tickets, capacity utilization, gross revenue (net of fees), and overall average paid price
- **Per-bucket detail table** -- Ticket counts, % of capacity, % of paid sales, sell-through (when explicit allocation limits are configured), and actual gross per tier
- **Dynamic pricing lift** -- For productions using dynamic pricing, how much additional revenue was earned above the flat entry-price baseline, broken down by bucket and in aggregate

**Key behaviors:**

- Toggle between **% of Paid Sales** (default) and **% of Capacity** to shift between "what did buyers choose?" and "how did each tier fill the house?"
- When a show is still running, a banner appears below its chart noting how many performances have completed
- Sell-through percentage only appears for tiers with explicit ticket limits configured -- it displays `—` for general-allocation tiers where no cap was set
- Ticket classes linked by dynamic pricing promotion triggers are grouped into a single bucket automatically

**Use cases:** Year-over-year pricing strategy comparison (e.g., this year's Who's Holiday vs. last year's). Evaluating whether your dynamic pricing tiers are generating lift or going unused. Understanding what share of your audience is buying at each price point vs. how much of the house each tier fills.

---

## March 2026

### Refund to Donation

**Available to:** Administrator, Box Office

A new action on ticket orders that converts a ticket purchase directly into a tax-deductible donation in a single step.

| Detail | Description |
|--------|-------------|
| **Where** | Ticket order detail page, in the red action group alongside Refund and Cancel |
| **Requirements** | Order must be Processed or Fulfilled, paid with a currency payment type (cash, check, or credit card), and the theater must be a 501(c)(3) |
| **Not available for** | Orders paid with Flex Pass or Membership |

**What happens when you click Refund to Donation:**

1. All reserved seats are released back to available inventory
2. Ticket line items are removed from the original order
3. A new donation order is created for the full amount paid
4. The original payment is moved to the donation order
5. The original ticket order is marked as Canceled with a note referencing the donation order
6. A donation receipt email is sent to the patron

!!! warning "Irreversible"
    This action cannot be undone. To reverse it, you would need to refund the donation order separately and re-enter the ticket order.

**Use cases:** Patron donates tickets they cannot use. Patron unable to exchange who prefers to donate. Partial group donation (use Split Order first, then Refund to Donation on the portion).

---

### Sample Email Preview

**Available to:** Administrator, Box Office

New buttons on the production edit page let you send yourself a sample confirmation email or follow-up email to preview exactly what patrons will see.

| Detail | Description |
|--------|-------------|
| **Where** | Edit Production page, below the "Additional Confirmation Message" and "Additional follow up message" fields |
| **Buttons** | "Send sample confirmation email" and "Send sample follow-up email" |
| **Requirements** | Production must be saved (not available on New Production form) |

**Key behaviors:**

- Uses your **current form values**, including unsaved edits -- you do not need to save first
- The page does not reload, preserving any other form changes
- Sample email includes placeholder data (Sample Customer, 2 tickets at $35, performance one week from today)
- Markdown formatting is rendered in the sample
- No permanent data is created -- temporary records are cleaned up automatically

**Use cases:** Preview confirmation messages before a show goes on sale. Test Markdown formatting. Iterate on messaging by sending multiple samples without saving.

---

## February 2026

### Performance Broadcast Email

**Available to:** Administrator, Box Office

Send custom email messages to all ticket holders for a specific performance directly from the production management screen.

| Detail | Description |
|--------|-------------|
| **Where** | Theaters > [Theater] > [Production] > Performances list, "Email Attendees" button on each performance |
| **Recipients** | All ticket holders with orders in Hold, Processed, Processing, or Fulfilled status who have valid email addresses |
| **From address** | Box office email or your personal email (must be a verified sender) |

**Features:**

- Pre-filled subject line (editable): "Important update regarding [Production] on [Date]"
- Markdown formatting support in the message body
- Recipient count displayed before sending
- Clean email layout with theater branding and greeting
- Emails queued and sent within minutes with automatic retry (up to 8 times)

**Use cases:** Venue changes, weather alerts, special guest announcements, parking updates, pre-show information, any time-sensitive communication for a specific performance's audience.

!!! tip "Best Practice"
    Use broadcast emails for timely, relevant operational information. For promotional content, use your regular marketing channels (MyEmma, social media).

---

## Earlier Changes

For information about features added before February 2026, contact your system administrator or refer to the internal release notes.
