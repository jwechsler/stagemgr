# Season Seating

!!! info "Required Role"
    Only **Administrators** can set a production to Season Seating status and manage orders during the season seating workflow.

**Navigation:** Productions > [Production Name] > Edit > Status > Season Seating

## Overview

Season Seating is a specialized production status used for managing subscriber seat assignments before a show goes on sale to the general public. It is designed for situations where season ticket holders receive priority seating and their orders need to be reviewed, adjusted, or assigned seats before any notifications are sent.

While a production is in Season Seating status, the system holds all orders in a pending state and suppresses patron communications. When the seating process is complete and the status is changed, a background job processes all held orders and notifies subscribers in bulk.

## When to Use Season Seating

Season Seating is appropriate when:

- You need to import or create subscriber orders in bulk before assigning seats
- Subscriber seat assignments require manual review or adjustment
- You want to prevent premature notifications while orders are being arranged
- The production uses reserved seating and subscribers need specific seat assignments

## The Season Seating Workflow

### Step 1: Set the Production to Season Seating

1. Navigate to the production's edit page
2. Set **Status** to **Season Seating**
3. Save the production

Once saved, the following behaviors take effect:

| Behavior | Description |
|----------|-------------|
| **Orders are held** | All new orders are placed on hold rather than being processed through the normal fulfillment workflow |
| **Emails are suppressed** | No confirmation emails, follow-up emails, or other patron notifications are sent |
| **Public visibility blocked** | The production does not appear on the public website |
| **Admin-only access** | Only Administrators can create and manage orders for this production |

### Step 2: Create or Import Orders

With the production in Season Seating status, create subscriber orders:

- **Bulk import:** Use the order import tool to load subscriber orders from a spreadsheet or external system. Imported orders are automatically held.
- **Manual entry:** Administrators can create individual orders through the box office interface. These orders are also placed on hold.

All orders created during this phase appear in the orders list with a held/pending status.

### Step 3: Assign Seats and Review Orders

With all subscriber orders in the system:

1. Review each order to verify accuracy (patron information, ticket classes, quantities)
2. For reserved seating productions, assign specific seats to each subscriber
3. Make any necessary adjustments to orders (changes, upgrades, seat swaps)
4. Resolve any conflicts (duplicate seats, overallocated sections, accessibility needs)

!!! tip "Work Through Systematically"
    Process subscribers in a consistent order -- by section, row, or subscription tier. This helps avoid seat conflicts and makes it easier to track progress.

### Step 4: Finalize Season Seating

When all subscriber orders are reviewed and seats are assigned:

1. Navigate to the production's edit page
2. Change **Status** from Season Seating to **Active** (or another appropriate status)
3. Save the production

This triggers the **FinalizeSeasonSeating** background job.

!!! warning "This Action Cannot Be Undone"
    Changing the status away from Season Seating immediately triggers the finalization job. You cannot return to Season Seating status to make further changes to held orders. Ensure all subscriber orders are correct before changing the status.

### What the FinalizeSeasonSeating Job Does

The background job performs these actions automatically:

1. **Processes all held orders:** Each order that was on hold is moved through the standard fulfillment workflow (from held to processed/fulfilled).
2. **Sends notifications:** Confirmation emails are sent to all subscribers whose orders were held. Patrons receive their seat assignments, order details, and any production-specific messaging (confirmation message, etc.).
3. **Updates house counts:** Performance house counts are recalculated to reflect the processed subscriber orders.

The job runs in the background and may take several minutes depending on the number of orders. You can monitor progress through the Resque job dashboard.

## After Finalization

Once the FinalizeSeasonSeating job completes:

- **Subscriber orders** are fully processed and patrons have been notified
- **Remaining inventory** is available for public sale (if the status was changed to Active)
- **House counts** reflect both subscriber and public sales
- **Normal order processing** resumes -- new orders are processed immediately as usual

## Important Considerations

### Planning the Timeline

Build enough time into your schedule for the season seating process:

1. Create the production and performances
2. Set status to Season Seating
3. Import/create subscriber orders (allow time for data preparation)
4. Assign seats and review (allow time for adjustments and conflict resolution)
5. Finalize and open public sales

### Reserved vs. General Admission

Season Seating works with both seating modes but is most commonly used with reserved seating. For general admission productions, the workflow is simpler since there are no individual seat assignments to manage -- but the hold-and-release mechanism still applies.

### Communication to Subscribers

Since all notifications are suppressed during the season seating phase, consider communicating with subscribers through other channels (email newsletter, phone) to let them know when to expect their seat assignment confirmations.

### Monitoring the Finalization Job

If the finalization job encounters errors (e.g., a payment processing issue on a held order), those orders remain in their held state. Check the Resque failure queue for details:

```
Resque::Failure.all(0, 25)
```

Failed orders may need manual intervention through the box office interface before they can be completed.

!!! tip "Test with a Small Batch"
    If this is your first time using Season Seating, consider testing the full workflow with a handful of orders before importing the entire subscriber list. This helps identify any issues with your data or seat map before processing hundreds of orders.
