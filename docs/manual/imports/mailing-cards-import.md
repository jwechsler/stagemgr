# Mailing List Signup Cards Import

!!! info "Required Role"
    **Administrator** or **Box Office** can run mailing list signup card imports.

**Navigation:** Options > Imports > Mailing List Signup Cards Import

## Purpose

This import loads customer contact information collected from **physical mailing list signup cards** at performances or events. It creates customer records, associates them with a production, and automatically adds them to the production's email marketing list in MyEmma.

Use this import after collecting signup cards at a show or event to digitize them into your customer database and marketing lists in one step.

## User Options

| Option | Required | Description |
|--------|----------|-------------|
| **Production Association** | Yes | Select the production where mailing list signups were collected |
| **File Upload** | Yes | CSV file containing mailing list signup data |

## Required CSV Headers

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

!!! warning "Different Header Names"
    Note that this import uses different header names than the TRG Arts import. For example, `Address1` instead of `Address`, `State` instead of `StateCode`, `Zip` instead of `PostalCode`, and `Email` instead of `EmailAddress1`. Use the exact headers listed above.

## How It Works

### Data Processing

1. Each row is matched against existing customer records by **email address first**.
2. If a match is found, the existing record is updated with any new information.
3. If no match is found, a new customer contact record is created.
4. Automatic duplicate detection and merging prevents creating duplicate records.
5. All imported contacts are marked as **attendees** of the selected production.
6. All imported contacts are added to the production's **MyEmma email marketing list**.

### MyEmma Integration

The import automatically enrolls each contact in the production's designated MyEmma email group. This means:

- Contacts begin receiving email marketing campaigns for the production immediately
- No manual step is required to add them to the mailing list
- If MyEmma is not configured for the production, the email list enrollment step is skipped

!!! tip "One Step from Card to Campaign"
    This import is designed to close the loop between collecting a physical signup card and enrolling the patron in email marketing -- no intermediate steps required.

## Expected Outcome

- Customer contact records are created or updated in the address database
- All contacts are marked as attendees of the selected production
- All contacts are automatically enrolled in the production's email marketing campaigns
- If a fatal error halts the import, the imports page status note records the failure (this importer does not produce a per-row result file — see [Result File](imports-overview.md#result-file) for the importers that do)

## Example CSV

```csv
FirstName,LastName,FullName,Address1,Address2,Address3,City,State,Zip,Email,HomePhone
Sarah,Johnson,,456 Elm St,Apt 2B,,Chicago,IL,60657,sarah@example.com,773-555-0300
Michael,Chen,,789 Pine Rd,,,Skokie,IL,60076,mchen@example.com,847-555-0400
```

## Best Practices

1. **Transcribe carefully.** Handwritten signup cards can be hard to read. Double-check email addresses in particular -- a typo means the patron will not receive marketing emails.

2. **Import promptly.** Import signup cards within a few days of collecting them so that patrons receive follow-up communications while the show is still fresh.

3. **Use one CSV per production.** Since a production association is required, create separate CSV files if you collected cards at multiple productions.
