# External Contact Data Import

!!! info "Required Role"
    **Administrator** or **Box Office** can run external contact data imports.

**Navigation:** Options > Imports > External Contact Data Import

## Purpose

This import loads comprehensive customer contact data from external systems or databases into Stagemgr. It supports **household records** with multiple people at the same address, and a **custom tagging system** for organizing and cross-referencing imported data.

Use this import when migrating contacts from another ticketing system, CRM, donor management platform, or any external data source.

## User Options

| Option | Required | Description |
|--------|----------|-------------|
| **Theater Association** | Yes | Select the theater to associate all imported contacts with |
| **File Upload** | Yes | CSV file containing external contact data |

## Required CSV Headers

### Primary Contact Fields

| Header | Description |
|--------|-------------|
| `ExternalId` | External system identifier (creates an "ExternalId" tag for cross-reference) |
| `FirstName` | Primary contact's first name |
| `MiddleName` | Primary contact's middle name |
| `LastName` | Primary contact's last name |
| `FullName` | Complete name (overrides individual name fields if provided) |
| `EmailAddress1` | Primary contact's email address |
| `Phone` | Contact phone number |

### Second Household Member Fields

| Header | Description |
|--------|-------------|
| `FirstName2` | Second household member's first name |
| `MiddleName2` | Second household member's middle name |
| `LastName2` | Second household member's last name |
| `FullName2` | Second household member's complete name |
| `EmailAddress2` | Second household member's email address |

### Address Fields

| Header | Description |
|--------|-------------|
| `Address` | Street address line 1 |
| `Address2` | Street address line 2 |
| `City` | City name |
| `StateCode` | State abbreviation (2 letters) |
| `PostalCode` | ZIP code |

### Custom Tag Fields

| Header | Description |
|--------|-------------|
| `Tag1` | Custom tag label for categorization |
| `TagValue1` | Value for custom tag 1 |
| `Tag2` | Second custom tag label |
| `TagValue2` | Value for custom tag 2 |

## How It Works

### Household Support

When a row includes both primary contact fields (`FirstName`, `LastName`) and second household member fields (`FirstName2`, `LastName2`), the import creates **two separate customer records**:

- Both records share the same address
- Both records receive the same custom tags
- Each record has its own email address (`EmailAddress1` and `EmailAddress2`)
- Both are associated with the selected theater

!!! tip "When to Use Household Fields"
    Use the second household member fields when your source data includes couples or families at the same address. This gives each person their own record for individual communications, while preserving the shared address.

### External ID Tracking

The `ExternalId` field creates a tag on each imported record that preserves the original system's identifier. This is valuable for:

- Cross-referencing records between Stagemgr and your source system
- Identifying records during future imports from the same source
- Auditing and data reconciliation

### Custom Tags

The `Tag1`/`TagValue1` and `Tag2`/`TagValue2` fields let you attach arbitrary metadata to imported records. Common uses include:

- Source system name (e.g., Tag1: "Source", TagValue1: "Salesforce")
- Donor status (e.g., Tag1: "DonorLevel", TagValue1: "Gold")
- Import batch identifier (e.g., Tag1: "ImportBatch", TagValue1: "2026-03")

### Data Processing

1. Each row is matched against existing customer records using standard duplicate detection criteria.
2. If a match is found, the existing record is updated.
3. If no match is found, a new customer record is created.
4. Duplicate records found during processing are automatically merged.
5. Character encoding issues in header names are automatically handled.

## Expected Outcome

- Customer records are created with custom tags for organization
- External IDs are preserved as tags for cross-system reference
- Household members receive separate records sharing the same address and tags
- All contacts are associated with the selected theater
- An error report is emailed to you if any rows could not be processed

## Example CSV

```csv
ExternalId,FirstName,MiddleName,LastName,FullName,FirstName2,MiddleName2,LastName2,FullName2,EmailAddress1,EmailAddress2,Phone,Address,Address2,City,StateCode,PostalCode,Tag1,TagValue1,Tag2,TagValue2
1001,Jane,,Smith,,Robert,,Smith,,jane@example.com,robert@example.com,312-555-0100,123 Main St,,Chicago,IL,60614,Source,Salesforce,,
1002,Maria,,Garcia,,,,,,maria@example.com,,773-555-0200,456 Oak Ave,Apt 3,Evanston,IL,60201,DonorLevel,Gold,,
```
