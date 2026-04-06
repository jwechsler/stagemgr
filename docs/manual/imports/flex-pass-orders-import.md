# Flex Pass Orders Import

!!! info "Required Role"
    **Administrator** or **Box Office** can run flex pass order imports.

**Navigation:** Options > Imports > Flex Pass Orders Import

## Purpose

This import creates **flex pass orders** for existing or new customers in bulk. All imported orders are automatically processed, giving customers active flex passes they can use for future ticket purchases.

Use this import when you need to set up flex passes for a large group -- for example, at the start of a season when flex pass sales from an external system need to be loaded, or when migrating flex pass records from another platform.

## User Options

| Option | Required | Description |
|--------|----------|-------------|
| **Theater Association** | Yes | Select the theater for flex pass offer lookup and customer association |
| **Payment Type** | No | Select a payment method for the flex pass orders |
| **File Upload** | Yes | CSV file containing flex pass order data |

## Required CSV Headers

| Header | Description |
|--------|-------------|
| `ExternalId` | External system identifier for customer lookup (optional if using Id) |
| `Id` | Existing customer address ID (takes precedence over ExternalId if provided) |
| `FlexPassOffer` | Name of the flex pass offer (must match an existing offer in the system) |
| `Code` | Optional custom flex pass code (system generates one if not provided) |
| `EmailAddress` | Customer's email address |
| `FullName` | Complete customer name |
| `LastName` | Customer's last name (required if FullName not provided) |
| `FirstName` | Customer's first name (required if FullName not provided) |
| `MiddleName` | Customer's middle name (optional) |
| `Address` | Street address line 1 |
| `Address2` | Street address line 2 |
| `City` | City name |
| `State` | State name or abbreviation |
| `ZipCode` | ZIP code |
| `Phone` | Contact phone number |

## How It Works

### Customer Matching

The import identifies customers using the same priority as bulk orders:

1. **Id field** -- If a Stagemgr address ID is provided, that record is used.
2. **ExternalId field** -- If provided, the system searches for a tagged customer.
3. **New record creation** -- If no match is found, a new customer is created.

### Flex Pass Offer Validation

The `FlexPassOffer` field must match the **exact name** of a flex pass offer configured for the selected theater. If the offer name does not match, the row fails and appears in the error report.

!!! tip "Check Offer Names"
    Before preparing your CSV, go to **Passes > Flex Pass Offers** and note the exact name of each offer. The import matches on the offer name string, so it must be precise -- including capitalization and spacing.

### Order Processing

All flex pass orders are **automatically processed** to PROCESSED status, regardless of whether a payment type is selected. This means:

- Flex passes are immediately active and usable
- No manual processing step is required after import
- Orders with a payment type have the payment recorded; orders without are processed as unpaid

### Custom Codes

| Code Field | Behavior |
|------------|----------|
| **Populated** | The provided code is assigned to the flex pass |
| **Empty** | The system generates a unique flex pass code automatically |

Custom codes are useful when migrating from another system where patrons already know their pass codes.

### Email Suppression

!!! note "No Receipts Sent During Import"
    Receipt emails are **suppressed** during bulk import to prevent sending a flood of notifications. Patrons will not receive an email confirming their flex pass order. If you need to notify patrons, do so separately after the import completes.

## Expected Outcome

- Flex pass orders are created and automatically processed
- Customers receive active flex passes usable for future ticket purchases
- Custom flex pass codes are assigned if provided, otherwise system-generated
- No email receipts are sent during the import
- An error report is emailed to you for any rows that could not be processed

## Example CSV

```csv
ExternalId,Id,FlexPassOffer,Code,EmailAddress,FullName,LastName,FirstName,MiddleName,Address,Address2,City,State,ZipCode,Phone
,,6-Pack Flex Pass,FP-2026-001,jane@example.com,,Smith,Jane,,123 Main St,,Chicago,IL,60614,312-555-0100
1001,,6-Pack Flex Pass,,mchen@example.com,,Chen,Michael,,456 Oak Ave,Apt 3,Evanston,IL,60201,847-555-0200
```

## Best Practices

1. **Verify the offer exists.** The `FlexPassOffer` name must exactly match an existing offer for the selected theater. A mismatch causes the entire row to fail.

2. **Use custom codes for migrations.** If patrons already have flex pass codes from a previous system, populate the `Code` column to preserve continuity.

3. **Communicate separately.** Since receipt emails are suppressed, plan a separate communication to let patrons know their flex passes are active.
