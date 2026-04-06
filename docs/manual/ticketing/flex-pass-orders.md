# Flex Pass Orders

!!! info "Role: Box Office Staff, Administrators"
    Flex passes allow patrons to pre-purchase multiple admissions that can be redeemed for tickets to future performances. This page covers purchasing, managing, and redeeming flex passes.

**Navigation:** Stagemgr > Orders > Flex Pass Orders > New Flex Pass Order

## Overview

A flex pass is a pre-paid, multi-use ticket voucher. The patron purchases a flex pass order, which generates a unique code. That code can then be used as a payment method when creating ticket orders, with each redemption decrementing the remaining uses on the pass.

## Purchasing a Flex Pass

### Step 1: Customer Lookup

1. In the **Address** section, begin typing the patron's name
2. Select the matching record or enter new patron details

### Step 2: Flex Pass Configuration

The flex pass order form includes the following fields:

| Field | Description |
|-------|-------------|
| **Number of Uses** | How many times the pass can be redeemed for tickets |
| **Expiration Date** | The date after which the pass can no longer be used |
| **Code Prefix** (optional) | An optional prefix for the generated flex pass code |

### Step 3: Payment

Process payment for the flex pass using any standard payment method:

- Credit card
- Cash
- Check
- External payment

See [Payment Processing](payment-processing.md) for details.

### Step 4: Submit

1. Review the order details
2. Submit the flex pass order
3. The order is created with status **Processed**
4. A **FlexPass** record is created with a unique code

## The Flex Pass Code

When a flex pass order is processed, the system generates a unique code:

| Property | Description |
|----------|-------------|
| **Format** | 6 alphanumeric characters, optionally preceded by a prefix |
| **Example (no prefix)** | `A3X7K2` |
| **Example (with prefix)** | `SEASON-A3X7K2` |
| **Uniqueness** | Each code is unique across the system |

!!! tip "Communicating the Code"
    Provide the flex pass code to the patron via their confirmation email or printed receipt. They will need this code to redeem tickets.

## Flex Pass Properties

Each flex pass has the following attributes:

| Property | Description |
|----------|-------------|
| **Code** | The unique redemption code |
| **Expiration Date** | Date the pass expires and can no longer be used |
| **Uses Remaining** | Number of remaining redemptions |
| **Active** | Whether the pass is currently active |
| **Created Date** | When the pass was purchased |

## Redeeming a Flex Pass

Flex passes are redeemed during ticket order creation. The flex pass code is entered as the payment method.

### Redemption Process

1. Create a new ticket order (see [Creating a Ticket Order: GA](creating-ticket-order-ga.md) or [Reserved Seating](creating-ticket-order-rs.md))
2. Fill in the patron information and select the performance
3. Choose tickets/seats as usual
4. In the **Payment** section, select **Flex Pass** as the payment type
5. Enter the **Flex Pass Code** in the provided field
6. The system validates the code and checks:
    - Is the code valid?
    - Is the pass active?
    - Has the pass expired?
    - Are there remaining uses?
7. If valid, submit the order
8. The flex pass uses remaining count is decremented

### Validation Rules

| Check | Failure Message |
|-------|----------------|
| Code not found | "Invalid flex pass code" |
| Pass is inactive | "This flex pass is no longer active" |
| Pass has expired | "This flex pass has expired" |
| No uses remaining | "This flex pass has no remaining uses" |

!!! warning "One Use Per Order"
    Each redemption uses one "use" from the flex pass, regardless of how many tickets are on the order. A flex pass with 4 uses can be redeemed for 4 separate ticket orders.

## Managing Flex Passes

### Checking Pass Status

To check the current status of a flex pass:

1. Navigate to the flex pass order
2. The order detail page shows the flex pass record with current uses remaining, expiration date, and active status

### Deactivating a Pass

If a flex pass needs to be deactivated (e.g., lost or stolen):

1. Navigate to the flex pass order or flex pass record
2. Set the **Active** flag to false
3. The pass can no longer be redeemed

### Refunding a Flex Pass Order

If a flex pass order is refunded:

- The flex pass is deactivated
- Any unredeemed uses are lost
- Ticket orders already redeemed with the pass are not affected

!!! warning "Partial Usage"
    If a patron has already redeemed some uses before requesting a refund, the previously created ticket orders remain valid. Only the flex pass itself is deactivated.

## Flex Pass and Order Lifecycle

| Event | Effect on Flex Pass |
|-------|-------------------|
| Flex pass order created | FlexPass record created, uses set to purchased amount |
| Ticket order redeemed | Uses remaining decremented by 1 |
| Ticket order refunded | Uses remaining restored by 1 |
| Flex pass order refunded | Pass deactivated, remaining uses voided |
| Pass expires | Pass cannot be used for new redemptions; existing orders unaffected |

## Reporting

Flex pass activity appears in several reports:

- **Flex Pass Usage Report** -- Shows all redemptions by pass
- **Sales Reports** -- Flex pass payments appear as a separate payment category
- **Outstanding Passes** -- Lists active passes with remaining uses

## Troubleshooting

| Issue | Resolution |
|-------|------------|
| Patron says code is not working | Verify the code, check active status, expiration, and remaining uses |
| Uses remaining is wrong | Check if a redeemed ticket order was refunded (which restores a use) |
| Need to extend expiration | Edit the flex pass record to update the expiration date |
| Patron lost their code | Look up the flex pass order by patron name to find the code |
| Want to add more uses | Create a new flex pass order rather than modifying the existing one |
