# Royalty Report

!!! info "Roles: All Users"
    This report is available to all authenticated users under the **Show Reports** permission group.

**Navigation:** Admin Menu > Reports > Royalty Report

---

## Purpose

The Royalty Report calculates royalty payments owed to rights holders (playwrights, licensing
companies) for a production. It provides a per-performance breakdown of ticket sales using
**royalty pricing** rather than the actual ticket prices patrons paid, then applies a configurable
royalty percentage to determine the amount due.

This report is useful for:

- Generating royalty statements for licensing agreements
- Calculating per-performance royalty obligations
- Accounting for subscription and flex pass tickets at their royalty-agreed value
- Tracking net royalty-eligible revenue after fees and discounts

## Prerequisites

Before generating a royalty report, configure the following:

### Royalty Percent (on the Production)

Set the **Royalty %** field on the production edit form under House Management. This is the
percentage applied to net revenue to calculate the royalty amount. For example, enter `8.00`
for an 8% royalty rate.

If royalty percent is not set, the Royalty column will show $0.00 for all performances.

### Royalty Amount (on Ticket Classes)

Optionally set a **Royalty Amount** on each ticket class. This overrides the ticket price for
royalty calculation purposes. The royalty amount is **exclusive of facility fee**.

When no royalty amount is set, the report uses `ticket price - facility fee` as the royalty
basis. See [Ticket Classes](../productions/ticket-classes.md#royalty-amount) for details.

## Generating the Report

1. Navigate to **Admin Menu > Reports**.
2. In the **Royalty Report** section, search for and select a production using the [production picker](../productions/finding-productions.md#the-production-search-picker).
3. Click **Show** to display results on screen, or **Download** to export a CSV file.

## Columns

| Column | Description |
|---|---|
| **Performance Code** | The performance identifier |
| **Performance Date** | The date of the performance |
| **Performance Time** | The start time of the performance |
| **Ticket Class Columns** | One column per ticket class that had sales during the run, showing the number of tickets sold. Classes with zero sales are omitted. |
| **Paid** | Total number of tickets sold for the performance |
| **Gross** | Total revenue calculated at royalty prices, with facility fees deducted for ticket classes that do not have an explicit royalty amount. Discounts are applied before facility fee deduction. |
| **Processing** | Total credit card processing fees for the performance |
| **Net** | Gross minus processing fees |
| **Royalty** | Net multiplied by the production's royalty percent |

The on-screen view omits the ticket class breakdown columns. The CSV download includes them.

## How Gross Is Calculated

The Gross column differs from the Production Sales By Performance report. Instead of using the
actual amount paid by patrons, the royalty report recalculates each order's gross using royalty
pricing:

1. **For each ticket line item:** Use the ticket class's royalty amount if set, otherwise use
   the ticket price.
2. **Apply discounts:** If the order used a special offer (percent off, amount off), the
   discount is recalculated against the royalty prices -- not derived from the actual order
   total.
3. **Deduct facility fees:** For ticket classes without an explicit royalty amount, the
   facility fee is deducted (since the ticket price includes it, but royalty calculations
   should exclude it).

### Example

A production has two ticket classes:

| Class | Ticket Price | Facility Fee | Royalty Amount |
|---|---|---|---|
| GA (General Admission) | $35.00 | $3.00 | *(not set)* |
| SUB (Subscription) | $0.00 | $0.00 | $25.00 |

An order for 2 GA tickets with a 10% off coupon:

- Royalty ticket total: 2 x $35.00 = $70.00
- Discount recalculated on royalty total: $70.00 x 10% = -$7.00
- After discount: $63.00
- Facility fee deduction: 2 x $3.00 = -$6.00
- **Royalty gross: $57.00**

An order for 1 SUB ticket (no discount):

- Royalty ticket total: 1 x $25.00 = $25.00
- No facility fee deduction (royalty amount is set explicitly)
- **Royalty gross: $25.00**

## Special Cases

### Split Orders

When an order is split, each resulting order has the original discount baked into its ticket
price. The royalty report calculates the proportional royalty amount using the ratio of the
split price to the original ticket price.

### Exchanged Orders

Both the original (exchanged) order and the replacement order appear in the report. The
original order's payments are offset to zero, so its royalty gross is $0.00. The replacement
order contributes its own royalty gross at the new performance.

### Orders Without Ticket Revenue

Orders where total payments are zero or negative (e.g., fully refunded or offset by exchange
payments) report a royalty gross of $0.00.

## Related Pages

- [Reports Overview](reports-overview.md)
- [Production Sales By Performance](production-sales.md)
- [Ticket Classes](../productions/ticket-classes.md)
