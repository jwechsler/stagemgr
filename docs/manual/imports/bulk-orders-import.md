# Bulk Orders Import

!!! info "Required Role"
    **Administrator** or **Box Office** can run bulk order imports.

**Navigation:** Options > Imports > Bulk Orders Import

## Purpose

This import creates **complete ticket orders** with customer information, seating assignments, and payment processing. It supports both reserved seating and general admission productions and can automatically process orders or hold them for manual review.

Use this import when you need to load a large number of ticket orders at once -- for example, migrating orders from another system, processing group sales, or entering season seating assignments in bulk.

## User Options

| Option | Required | Description |
|--------|----------|-------------|
| **Theater Association** | Yes | Select the theater for all imported orders |
| **Payment Type** | No | Select a payment method to process orders immediately, or leave blank to place on hold |
| **Add to Email List** | No | Check to automatically add customers to email marketing lists (disabled for season seating) |
| **File Upload** | Yes | CSV file containing order data |

## Required CSV Headers

| Header | Description |
|--------|-------------|
| `ExternalId` | External system identifier (optional -- creates "External ID" tag) |
| `Id` | Existing customer address ID (takes precedence over ExternalId if provided) |
| `ProductionCode` | Production identifier for the theater |
| `PerformanceCode` | Specific performance identifier for seating |
| `Seating` | Comma-delimited list of seat locations, e.g., `A1,A2,A3` (optional for general admission) |
| `NumberOfTickets` | Number of tickets (required for general admission; overridden by Seating count for reserved seating) |
| `TicketClass` | Ticket class code (pricing tier) |
| `FirstName` | Customer's first name |
| `MiddleName` | Customer's middle name |
| `LastName` | Customer's last name |
| `FullName` | Complete name (overrides individual name fields if provided) |
| `EmailAddress` | Customer's email address |
| `Phone` | Contact phone number |
| `Address` | Street address line 1 |
| `Address2` | Street address line 2 |
| `City` | City name |
| `State` | State abbreviation |
| `ZipCode` | ZIP code |
| `Tag1` | Custom tag label |
| `TagValue1` | Value for custom tag 1 |
| `Tag2` | Second custom tag label |
| `TagValue2` | Value for custom tag 2 |

## How It Works

### Customer Matching

The import identifies customers in this priority order:

1. **Id field** -- If an existing Stagemgr address ID is provided, that record is used directly.
2. **ExternalId field** -- If provided, the system searches for a customer tagged with that external ID.
3. **New record creation** -- If neither ID matches, a new customer record is created from the name, email, address, and phone fields.

### Reserved Seating vs. General Admission

| Scenario | Behavior |
|----------|----------|
| **Seating column populated** | The system assigns the listed seats. The number of tickets equals the number of seats listed, regardless of `NumberOfTickets`. |
| **Seating column empty** | The system creates a general admission order using the `NumberOfTickets` value. |

The import validates seat availability and prevents double-booking. If a requested seat is already assigned, the row will fail and appear in the error report.

### Order Processing Logic

The import handles orders differently depending on whether the production uses season seating:

#### Season Seating Productions

!!! warning "Season Seating Override"
    All orders for **season seating** productions are automatically placed on **HOLD** status, regardless of the payment type selected or email list settings. This ensures season seating orders receive manual review before processing.

- Orders are placed on HOLD
- Customers are **not** added to email lists
- No immediate email notifications are sent

#### Regular Productions

| Payment Type Selected? | Result |
|------------------------|--------|
| **Yes** | Orders are processed immediately. Customers receive email confirmations. Added to email lists if the checkbox is checked. |
| **No** (left blank) | Orders are placed on HOLD for manual processing. |

### Error Handling

Rows that cannot be processed generate detailed error entries. Common failure reasons include:

- Invalid `ProductionCode` or `PerformanceCode`
- Requested seat already assigned to another order
- Invalid or unrecognized `TicketClass` code
- Missing required fields

## Expected Outcome

| Order Type | Status | Email Notifications | Email List |
|------------|--------|---------------------|------------|
| Season seating (any payment type) | HOLD | None | Not added |
| Regular with payment type | Processed | Confirmation sent | Added if checked |
| Regular without payment type | HOLD | None | Not added |

An error report is emailed to you for any rows that could not be processed.

## Example CSV

```csv
ExternalId,Id,ProductionCode,PerformanceCode,Seating,NumberOfTickets,TicketClass,FirstName,MiddleName,LastName,FullName,EmailAddress,Phone,Address,Address2,City,State,ZipCode,Tag1,TagValue1,Tag2,TagValue2
,,ALLY,ALLY-0315,"A1,A2",2,GA,Jane,,Smith,,jane@example.com,312-555-0100,123 Main St,,Chicago,IL,60614,,,,
,,ALLY,ALLY-0315,,4,GA,Michael,,Chen,,mchen@example.com,773-555-0200,456 Oak Ave,Apt 3,Evanston,IL,60201,Group,SpringGala,,
```

## Best Practices

1. **Validate seat names.** For reserved seating imports, make sure seat identifiers in the `Seating` column match the seat names in the production's seat map exactly.

2. **Test with a small batch first.** Before importing hundreds of orders, import 3--5 rows to verify everything maps correctly.

3. **Use HOLD for review.** When importing orders that need manual verification, leave the payment type blank so orders are placed on HOLD. Process them individually after review.
