# Frequently Asked Questions

!!! info "Reference"
    Answers to common operational questions about Stagemgr. For terminology definitions, see the [Glossary](glossary.md).

## Pricing and Ticket Classes

### How do I change a ticket price after sales have started?

Edit the ticket class to update the price. The new price applies to all **future** orders only -- existing orders retain the price they were sold at. Navigate to **Theaters > [Theater] > [Production] > Ticket Classes** and edit the relevant class.

!!! warning "Price Changes Are Not Retroactive"
    Changing a ticket class price does not affect orders that have already been placed. If you need to adjust a specific order's price, use the exchange workflow to move the patron to a different ticket class.

### How do I set up an early bird discount that expires automatically?

Use dynamic pricing with a time-based trigger. Create two ticket classes (e.g., "Early Bird" at $20 and "Regular" at $35), then make the Early Bird allocation shiftable with a "Shift Days Before Performance" value. When the trigger activates, new purchases automatically redirect to the Regular price. See [Dynamic Pricing](../productions/dynamic-pricing.md).

### Can I offer different prices for the same seat?

Yes. Multiple ticket classes can apply to the same seats. For general admission, different classes represent different price tiers for the same seats. For reserved seating, you can have different classes available for the same performance -- the price depends on which class the patron selects, not which seat they choose (unless you restrict classes to specific sections).

## Seating and Performances

### How do I move a patron to a different seat?

Use the **Exchange** function on the ticket order. This allows you to change the seat assignment, performance, or ticket class. If there is a price difference, the exchange calculates the differential automatically.

1. Open the ticket order
2. Click **Exchange**
3. Select the new performance, ticket class, and/or seats
4. Process the exchange (collecting or refunding any price difference)

### Why can't I see a production?

Productions are filtered by theater access. If you cannot see a production:

- **Theater Users**: You can only see productions belonging to theaters you are assigned to. Contact an administrator to verify your theater assignments.
- **All users**: Check the season filter -- you may be viewing a different season than the production belongs to.
- **New productions**: Verify the production was saved successfully and is associated with the correct theater.

### How do I add or remove a performance?

Navigate to **Theaters > [Theater] > [Production] > Performances**. Click **Add Performance** to create a new one, or click on an existing performance and use the delete option to remove it. Deleting a performance is only possible if no orders have been placed for it.

!!! tip "Duplicating Performances"
    If you need to add many performances with similar settings, use the **Duplicate** function on an existing performance rather than creating each one from scratch.

## Orders and Payments

### How do I find a patron's order?

Several search methods are available:

| Method | Navigation | Best For |
|--------|------------|----------|
| Order search | **Orders** menu | Searching by order number, patron name, or email |
| Customer record | **Customers > [Patron]** | Viewing all orders for a specific patron |
| Performance view | **Performance > Orders** | Finding orders for a specific show date |

### What happens when I cancel an order?

When you cancel an order:

1. **Seats are released** back to available inventory (for reserved seating)
2. **Ticket count is restored** to available (for general admission)
3. **Order status** changes to CANCELED
4. **No automatic refund** is issued -- cancellation and refund are separate actions. Cancel releases the inventory; refund returns the money.

!!! note "Cancel vs. Refund"
    Canceling an order does **not** refund the payment. To return money to the patron, use the **Refund** function separately, or use **Refund to Donation** if the patron wants to donate the value instead.

### Can I undo a refund?

No. Refunds cannot be reversed in Stagemgr once processed. If a refund was issued in error, you would need to create a new order for the patron and collect payment again.

### How do I handle a no-show?

Use the **Mark Unclaimed** function on the ticket order after the performance. This changes the order status from FULFILLED to UNCLAIMED, which is tracked in house management reports for attendance analysis.

1. Navigate to the order
2. Click **Mark Unclaimed**
3. The order status updates to UNCLAIMED

### How do season seating orders work?

Season seating is a production-level setting that changes how orders are handled:

1. **All imported orders go to HOLD** regardless of payment type selection
2. **Email list enrollment is disabled** for bulk-imported orders
3. **Pre-hold functionality** allows reserving seats before processing
4. **Batch processing** -- use the "Process Orders in Season Seating" function to process held orders in bulk

Season seating is designed for subscription-style sales where patrons commit to the same seats across multiple performances. See [Season Seating](../productions/season-seating.md) for details.

## Refunds and Exchanges

### What is the difference between a refund and an exchange?

| Action | What Happens | When to Use |
|--------|-------------|-------------|
| **Refund** | Money is returned, order is canceled, seats are released | Patron wants their money back |
| **Exchange** | Patron is moved to a different performance/seat/class, price differential is handled | Patron wants to attend a different show or sit elsewhere |
| **Refund to Donation** | Ticket order is canceled, payment is moved to a new donation order | Patron wants to donate the ticket value |

### Can I exchange tickets across different productions?

No. Exchanges are limited to performances within the **same production**. To move a patron to a different production, you would refund the original order and create a new order for the other production.

### How do I handle a partial refund?

Use the **Split Order** function first to separate the tickets being refunded from those being kept, then refund only the split-off portion.

1. Open the ticket order
2. Click **Split**
3. Select which tickets to separate into a new order
4. Click **Finalize Split**
5. Refund the new (split) order containing the tickets to return

## Customers and Data

### How do I merge duplicate customer records?

Administrators can merge customer records from the **Customers** section. Search for the duplicate records, select them, and use the **Merge Selected** action. The merge combines order history, tags, and contact information into a single record.

!!! warning "Merging Cannot Be Undone"
    Customer merges are permanent. Verify that the records are truly duplicates before merging.

### Why does a customer appear twice in search results?

Duplicate records occur when a patron provides different email addresses or name spellings across orders, when imports from different sources create separate records, or when manual data entry creates a new record instead of finding the existing one. Use the merge function to consolidate duplicates.

## Reports

### Why is my report taking so long?

Large reports run as [background jobs](../advanced/background-jobs.md) and are delivered by email when complete. Check your inbox -- the report may have already arrived. Allow up to 15 minutes for very large datasets.

### Why don't I see email addresses in my report?

**Administrators, Box Office, and Resident Company Users** see all email addresses. **Theater Users (non-resident)** only see addresses for patrons who opted into that theater's email marketing list. See [Permissions Matrix](permissions-matrix.md).
