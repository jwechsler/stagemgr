# Fulfilling Orders

!!! info "Role: Box Office Staff, House Managers"
    Fulfillment is the process of transitioning orders from Processed to Fulfilled status, indicating that the patron has received their tickets. This is the core will-call and check-in workflow.

**Navigation:** Admin > Orders > [Select Performance]

---

## Order State Transitions

Fulfillment moves orders through specific states in the Stagemgr order lifecycle:

| Transition | Action | When Used |
|------------|--------|-----------|
| Processed > Fulfilled | **Fulfill** | Patron picks up tickets or checks in at will-call |
| Fulfilled > Unclaimed | **Unclaim** | Revert a fulfillment (e.g., patron marked as arrived but hasn't actually checked in) |

!!! tip
    Only orders in **Processed** status can be fulfilled. Orders in Hold, New, or Processing states must first complete payment processing before they are eligible for fulfillment.

---

## Fulfilling Individual Orders

To fulfill a single order:

1. Navigate to the orders list for the relevant performance.
2. Locate the patron's order.
3. Click **Fulfill** on the order row.
4. The order status changes to **Fulfilled** immediately.

This is the typical workflow when a patron arrives at will-call and presents their name or confirmation number.

---

## Batch Fulfillment (fulfill_selected)

For efficiency during busy check-in periods, you can fulfill multiple orders at once:

1. Navigate to the orders list for the performance.
2. Select the checkbox next to each order you want to fulfill.
3. Click **Fulfill Selected**.
4. All selected orders transition from Processed to Fulfilled.

| Batch Feature | Description |
|---------------|-------------|
| Selection | Checkbox on each eligible order row |
| Action | Fulfill Selected button processes all checked orders |
| Eligibility | Only Processed orders are affected; other statuses are skipped |
| Speed | All selected orders are updated in a single operation |

!!! tip
    Batch fulfillment is especially useful when printing tickets for an entire performance. After printing, select all printed orders and fulfill them in one action. See [Printing Tickets](printing-tickets.md).

---

## Unclaiming Orders

If an order was fulfilled in error (e.g., wrong patron, premature check-in), you can revert it:

1. Locate the fulfilled order.
2. Click **Unclaim** on the order row.
3. The order status changes to **Unclaimed**.

### Batch Unclaim (unclaim_selected)

Similar to batch fulfillment, you can unclaim multiple orders at once:

1. Select the checkbox next to each fulfilled order to revert.
2. Click **Unclaim Selected**.
3. All selected orders transition from Fulfilled to Unclaimed.

!!! warning
    The Unclaimed state is distinct from Processed. An unclaimed order indicates that it was once marked as fulfilled but was then reverted. Use this for tracking no-shows or fulfillment errors, not for routine order management.

---

## Will-Call Workflow

The standard will-call process uses fulfillment as follows:

1. **Before doors open**: Print tickets for all Processed orders (see [Printing Tickets](printing-tickets.md)). Organize printed tickets alphabetically by patron last name.
2. **Patron arrives**: Search for the patron's name in the will-call stack.
3. **Hand over tickets**: Give the patron their printed tickets.
4. **Fulfill the order**: Mark the order as Fulfilled to record the pickup.
5. **No-show handling**: After the performance starts, any unfulfilled orders represent patrons who did not pick up their tickets.

---

## Order States Reference

| State | Meaning | Can Fulfill? | Can Unclaim? |
|-------|---------|:------------:|:------------:|
| New | Order just created | No | No |
| Processing | Payment in progress | No | No |
| Hold | Reserved, awaiting payment | No | No |
| Processed | Payment complete, tickets ready | Yes | No |
| Fulfilled | Tickets delivered to patron | No | Yes |
| Unclaimed | Previously fulfilled, then reverted | No | No |

---

## Impact on House Counts

Fulfillment does not change house count numbers. A ticket counts as "sold" from the moment the order reaches Processed status, regardless of whether it has been fulfilled. The fulfillment step is purely operational -- it tracks whether the patron has physically received their tickets.

| House Count Metric | Affected by Fulfillment? |
|-------------------|:------------------------:|
| Sold count | No |
| Held count | No |
| Remaining | No |

---

## Tips for Busy Performances

- **Pre-sort will-call**: Print and organize tickets before doors open to minimize wait times.
- **Use batch fulfill**: After handing out a group of tickets, select them all and fulfill in one action.
- **Delegate check-in**: Multiple staff members can fulfill orders simultaneously from different computers.
- **Monitor remaining**: Keep the House Management dashboard open to track how many patrons are still expected.
