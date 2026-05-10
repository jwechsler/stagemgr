# TRG Arts Order File Import

!!! info "Required Role"
    **Administrator** or **Box Office** can run TRG Arts imports.

**Navigation:** Options > Imports > TRG Arts Order File Import

## Purpose

This import updates customer contact records with NCOA (National Change of Address) corrected addresses from TRG Arts data files. Optionally, it can also mark imported contacts as attendees of a specific production -- without creating actual ticket orders.

Use this import when you have attendee lists or address correction data but not complete ticketing transaction records.

## User Options

| Option | Required | Description |
|--------|----------|-------------|
| **Production Association** | No | Select a production to mark all imported contacts as attendees of that production. Leave blank to update addresses only. |
| **File Upload** | Yes | CSV file containing attendee and address data |

## Required CSV Headers

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
| `Zip4` | ZIP+4 extension (optional -- appended to PostalCode if provided) |
| `EmailAddress1` | Primary email address |
| `HomePhone` | Phone number |

## How It Works

### Data Processing

1. Each row in the CSV is matched against existing customer records using name, email, and address criteria.
2. If a match is found, the existing record is updated with the NCOA-corrected address data.
3. If no match is found, a new customer contact record is created.
4. Automatic duplicate detection and merging runs to prevent creating duplicate records.

### With a Production Selected

When you select a production in the import form:

- All imported contacts are additionally marked as **attendees** of that production
- This association is for reporting and marketing purposes only
- **No ticket orders are created** -- the contacts appear in attendee reports but have no order records

### Without a Production Selected

When no production is selected:

- Contact records are created or updated with corrected address data
- No production association is made

!!! tip "NCOA Updates"
    The primary value of this import is keeping your address database current. Run it periodically with fresh TRG Arts data to catch address changes from the USPS National Change of Address database.

## Expected Outcome

- Contact records are updated with corrected addresses
- If a production is selected, contacts are marked as attendees for reporting and marketing
- No ticket orders or financial records are created
- If a fatal error halts the import, the imports page status note records the failure (this importer does not produce a per-row result file — see [Result File](imports-overview.md#result-file) for the importers that do)

## Example CSV

```csv
FirstName,LastName,Prefix,FullName,Address,City,StateCode,PostalCode,Zip4,EmailAddress1,HomePhone
Jane,Smith,Ms.,,123 Main St,Chicago,IL,60614,1234,jane@example.com,312-555-0100
John,Doe,Mr.,,456 Oak Ave,Evanston,IL,60201,,john@example.com,847-555-0200
```

!!! note "FullName vs. FirstName/LastName"
    If both `FullName` and `FirstName`/`LastName` are provided, the individual name fields take precedence. `FullName` is used as a fallback when the first and last name fields are incomplete.
