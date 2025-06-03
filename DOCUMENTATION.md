# Stagemgr Import Functions Documentation

This document describes the import functions available to end-users at `/tickets/admin/imports`. These functions allow you to bulk import various types of data into the Stagemgr ticketing system.

## TRG Arts Order File Import

**Purpose**: Mark customer records as attendees of a specific production without creating actual ticket orders. This is used when you have attendee lists but not complete ticketing transaction data. Additionally, updates existing customer records with NCOA (National Change of Address) corrected addresses regardless of whether a production is selected.

**Required CSV Headers**:

| Header | Description |
|--------|-------------|
| `FirstName` | Attendee's first name |
| `LastName` | Attendee's last name |
| `Prefix` | Title/prefix (Mr., Ms., Dr., etc.) |
| `FullName` | Complete name (used if FirstName/LastName are incomplete) |
| `Address` | Street address |
| `City` | City name |
| `StateCode` | State abbreviation (e.g., IL, NY, CA) |
| `PostalCode` | ZIP code |
| `Zip4` | ZIP+4 extension (optional, will be appended to PostalCode) |
| `EmailAddress1` | Primary email address |
| `HomePhone` | Phone number |

**Data Processing**:
- Creates or updates customer contact records in the address database
- Automatically merges duplicate contacts based on matching criteria
- Updates existing customer records with NCOA corrected addresses
- **With Production Selected**: Additionally associates imported contacts as attendees of the specified production (attendee status only, no orders created)
- Maintains referential integrity by checking for existing records before creating new ones

**User Options**:
- **Production Association** (optional): Select a production to mark all imported contacts as attendees
- **File Upload**: CSV file containing attendee/address data

**Expected Outcome**: Contact records are updated with corrected addresses. If a production is selected, contacts are also marked as attendees of that production for reporting and marketing purposes, but no ticket orders are created.

## Mailing List Signup Cards Import

**Purpose**: Import customer contact information from physical mailing list signup cards collected at performances or events. Associates contacts with a specific production and automatically adds them to the production's email marketing list.

**Required CSV Headers**:

| Header | Description |
|--------|-------------|
| `FirstName` | Customer's first name |
| `LastName` | Customer's last name |
| `FullName` | Complete name (used if FirstName/LastName are incomplete) |
| `Address1` | Primary street address |
| `Address2` | Secondary address line (optional) |
| `Address3` | Additional address line (optional) |
| `City` | City name |
| `State` | State name or abbreviation |
| `Zip` | ZIP code |
| `Email` | Email address |
| `HomePhone` | Phone number |

**Data Processing**:
- Creates or updates customer contact records in the address database
- Matches existing customers by email address first, then creates new records if no match found
- Automatically merges duplicate contacts based on matching criteria
- Associates imported contacts as attendees of the specified production
- Automatically adds contacts to the production's MyEmma email marketing list

**User Options**:
- **Production Association** (required): Select the production for which mailing list signups were collected
- **File Upload**: CSV file containing mailing list signup data

**Expected Outcome**: Contact records are created/updated, marked as attendees of the production, and automatically enrolled in the production's email marketing campaigns.

## External Contact Data Import

**Purpose**: Import comprehensive customer contact data from external systems or databases. Supports household records with multiple people and custom tagging system for organizing imported data. Associates all imported contacts with a specific theater.

**Required CSV Headers**:

| Header | Description |
|--------|-------------|
| `ExternalId` | External system identifier (creates "ExternalId" tag for cross-reference) |
| `FirstName` | Primary contact's first name |
| `MiddleName` | Primary contact's middle name |
| `LastName` | Primary contact's last name |
| `FullName` | Complete name (overrides individual name fields if provided) |
| `FirstName2` | Second household member's first name |
| `MiddleName2` | Second household member's middle name |
| `LastName2` | Second household member's last name |
| `FullName2` | Second household member's complete name (overrides individual name fields if provided) |
| `EmailAddress1` | Primary contact's email address |
| `EmailAddress2` | Second household member's email address |
| `Phone` | Contact phone number |
| `Address` | Street address line 1 |
| `Address2` | Street address line 2 |
| `City` | City name |
| `StateCode` | State abbreviation (2 letters) |
| `PostalCode` | ZIP code |
| `Tag1` | Custom tag label for categorization |
| `TagValue1` | Value for custom tag 1 |
| `Tag2` | Second custom tag label |
| `TagValue2` | Value for custom tag 2 |

**Data Processing**:
- Creates separate customer records for each household member when both primary and secondary contacts are provided
- Automatically merges duplicate contacts based on matching criteria
- Creates custom tags for imported data organization and external system cross-referencing
- Associates all imported contacts with the specified theater
- Handles character encoding issues in header names

**User Options**:
- **Theater Association** (required): Select the theater to associate all imported contacts with
- **File Upload**: CSV file containing external contact data

**Expected Outcome**: Customer records are created with custom tags for organization, external ID tracking for system integration, and household relationship management. Both primary and secondary household members receive separate records sharing the same address and custom tags.

## Bulk Orders Import

**Purpose**: Import complete ticket orders with customer information and seating assignments. Creates actual ticket orders with payment processing, supporting both reserved seating and general admission. All orders are associated with a specific theater and can be automatically processed or held for manual review.

**Required CSV Headers**:

| Header | Description |
|--------|-------------|
| `ExternalId` | External system identifier (optional, creates "External ID" tag) |
| `Id` | Existing customer address ID (takes precedence over ExternalId if provided) |
| `ProductionCode` | Production identifier for the theater |
| `PerformanceCode` | Specific performance identifier for seating |
| `Seating` | Comma-delimited list of seat locations (e.g., "A1,A2,A3") - optional for general admission |
| `NumberOfTickets` | Number of tickets (required for general admission, overridden by Seating count for reserved seating) |
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

**Data Processing**:
- Creates or updates customer records using ID, ExternalId, or new record creation
- Creates actual ticket orders with proper order status transitions
- Handles both reserved seating (with specific seat assignments) and general admission
- Validates seat availability and prevents double-booking
- **Season Seating Handling**: All orders for season seating productions are automatically placed on HOLD status regardless of payment type selection and email list settings
- **Regular Production Handling**: Orders with a payment type are processed immediately; orders without payment type are placed on HOLD
- Generates detailed error reports for problematic rows

**User Options**:
- **Theater Association** (required): Select theater for all imported orders
- **Payment Type** (optional): Select payment method for processing orders, or leave blank to place on hold (ignored for season seating)
- **Add to Email List** (checkbox): Automatically add customers to email marketing lists (disabled for season seating orders)
- **File Upload**: CSV file containing order data

**Expected Outcome**: 
- **Season Seating Orders**: Always placed on HOLD status for manual review, customers not added to email lists, no immediate email notifications sent
- **Regular Orders with Payment Type**: Processed immediately, customers receive email confirmations, added to email lists if selected
- **Regular Orders without Payment Type**: Placed on HOLD for manual processing
- Error reports are generated for any problematic import rows

## Flex Pass Orders Import

**Purpose**: Import flex pass orders for existing or new customers. Creates flex pass orders that are automatically processed and provide flexible ticket purchasing benefits. Customer records must already exist in the system or be identifiable through external ID matching.

**Required CSV Headers**:

| Header | Description |
|--------|-------------|
| `ExternalId` | External system identifier for customer lookup (optional if using Id) |
| `Id` | Existing customer address ID (takes precedence over ExternalId if provided) |
| `FlexPassOffer` | Name of the flex pass offer (must match existing offer in system) |
| `Code` | Optional custom flex pass code (system generates if not provided) |
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

**Data Processing**:
- Creates or updates customer records using ID, ExternalId, or new record creation
- Creates flex pass orders that are automatically processed to PROCESSED status
- Validates that the specified FlexPassOffer exists in the system for the theater
- Assigns custom flex pass codes if provided, otherwise generates system codes
- All orders are processed immediately regardless of payment type selection
- Suppresses receipt emails to prevent notification during bulk import
- Generates detailed error reports for problematic rows

**User Options**:
- **Theater Association** (required): Select theater for flex pass offer lookup and customer association
- **Payment Type** (optional): Select payment method for the flex pass orders
- **File Upload**: CSV file containing flex pass order data

**Expected Outcome**: Flex pass orders are created and automatically processed. Customers receive active flex passes that can be used for future ticket purchases. No email receipts are sent during import to avoid bulk notifications. Error reports are generated for any problematic import rows.

## Donor Levels Import (LGL)

**Purpose**: Import donor tier information from Little Green Light (LGL) or other donor management systems. Updates existing customer records with current and previous fiscal year donation levels for use in house management reports and donor recognition.

**Required CSV Headers**:

| Header | Description |
|--------|-------------|
| `External constituent ID` | Stagemgr customer ID for direct matching (optional) |
| `Pref. Email` | Customer's preferred email address for matching (optional) |
| `First Name` | Customer's first name for record matching |
| `Last Name` | Customer's last name for record matching |
| `TG Tier Last Fiscal` | Donor tier level from previous fiscal year |
| `TG Tier This Fiscal` | Donor tier level for current fiscal year |

**Data Processing**:
- Matches existing customer records using a three-tier approach:
  1. Direct ID match using External constituent ID
  2. Email address matching if ID not found
  3. Name and email matching for duplicate detection
- Creates new customer records if no match is found
- Updates donor tier fields for both current and previous fiscal years
- Sets `donor_tier_updated_on` timestamp to track when donor information was last refreshed
- Automatically merges duplicate customer records found during processing
- Only processes records that have donor tier information in at least one fiscal year

**User Options**:
- **File Upload**: CSV file containing donor tier data from LGL export

**Expected Outcome**: Customer records are updated with current donor tier information for use in house management reports, donor recognition programs, and targeted marketing campaigns. Duplicate customer records are consolidated during the import process. Records are timestamped to indicate when donor information was last updated.

## General Import Notes

- All imports run as background jobs and may take several minutes to complete for large files
- Import progress and results are displayed on the imports page
- Error reports are automatically generated for problematic rows and emailed to the importing user
- CSV files must have proper headers as specified for each import type
- Character encoding issues are automatically handled where possible
- Duplicate detection and merging helps maintain data quality across imports