# Donor Levels Import (LGL)

!!! info "Required Role"
    **Administrator** or **Box Office** can run donor level imports.

**Navigation:** Options > Imports > Donor Levels Import

## Purpose

This import updates existing customer records with **donor tier information** from Little Green Light (LGL) or other donor management systems. It sets current and previous fiscal year donation levels, which are then used in house management reports and donor recognition.

Use this import to synchronize donor status from your fundraising platform into Stagemgr, so that box office and house management staff can see patron giving levels alongside ticketing data.

## User Options

| Option | Required | Description |
|--------|----------|-------------|
| **File Upload** | Yes | CSV file containing donor tier data from an LGL export |

!!! note "No Theater or Production Selection"
    Unlike other imports, the donor levels import does not require a theater or production selection. It operates solely on customer record matching.

## Required CSV Headers

| Header | Description |
|--------|-------------|
| `External constituent ID` | Stagemgr customer ID for direct matching (optional) |
| `Pref. Email` | Customer's preferred email address for matching (optional) |
| `First Name` | Customer's first name for record matching |
| `Last Name` | Customer's last name for record matching |
| `TG Tier Last Fiscal` | Donor tier level from previous fiscal year |
| `TG Tier This Fiscal` | Donor tier level for current fiscal year |

!!! warning "Headers Include Spaces and Periods"
    Note that these header names contain spaces and periods (e.g., `Pref. Email`, `First Name`). They must match exactly as shown above. This format corresponds to the standard LGL export.

## How It Works

### Three-Tier Customer Matching

The import uses a cascading approach to find the correct customer record:

| Priority | Method | Description |
|----------|--------|-------------|
| **1st** | Direct ID match | Uses `External constituent ID` as a Stagemgr address ID for exact lookup |
| **2nd** | Email match | Searches for a customer with a matching `Pref. Email` address |
| **3rd** | Name + email match | Uses first name, last name, and email together for duplicate detection |

If none of these methods finds a match, a **new customer record is created** from the available data.

### What Gets Updated

For each matched or created customer record, the import sets:

| Field | Source Column | Purpose |
|-------|--------------|---------|
| Previous fiscal year donor tier | `TG Tier Last Fiscal` | Historical donor recognition |
| Current fiscal year donor tier | `TG Tier This Fiscal` | Active donor recognition |
| Donor tier updated timestamp | (automatic) | Tracks when donor info was last refreshed |

### Processing Rules

- Only records that have donor tier information in **at least one fiscal year** are processed. Rows where both tier fields are empty are skipped.
- Duplicate customer records found during processing are **automatically merged**.
- The `donor_tier_updated_on` timestamp is set automatically, allowing you to determine when donor information was last refreshed.

## Where Donor Tiers Appear

Once imported, donor tier information is used throughout Stagemgr:

| Feature | Usage |
|---------|-------|
| **House Management Reports** | Donor level appears alongside patron name in seating charts and check-in lists |
| **Customer Record** | Donor tier is visible on the customer detail page |
| **Reports** | Donor tiers can be included in attendee and customer exports |
| **Marketing** | Donor status can inform targeted communications and special offers |

## Expected Outcome

- Customer records are updated with current donor tier information
- The `donor_tier_updated_on` timestamp records when the update occurred
- Duplicate customer records are consolidated during processing
- A result file (`donor_import_results_<your-file-name>.csv`) listing every row, with an `Error` column populated for any that failed, is emailed to you when one or more rows could not be processed. See [Result File](imports-overview.md#result-file) for the full naming rules and retry workflow.

## Example CSV

```csv
External constituent ID,Pref. Email,First Name,Last Name,TG Tier Last Fiscal,TG Tier This Fiscal
4523,jane@example.com,Jane,Smith,Gold,Platinum
,mchen@example.com,Michael,Chen,,Silver
,,Sarah,Johnson,Bronze,Bronze
```

In this example:

- Jane Smith is matched by her Stagemgr ID (4523), then her tier is updated from Gold to Platinum
- Michael Chen is matched by email, with no previous tier and a new Silver tier
- Sarah Johnson is matched by name, with Bronze tier in both years

## Best Practices

1. **Run periodically.** Import donor levels at the start of each fiscal year and after major fundraising campaigns to keep Stagemgr in sync with LGL.

2. **Include the Stagemgr ID when possible.** The `External constituent ID` provides the most reliable match. If your LGL export includes the Stagemgr customer ID, always populate this field.

3. **Verify after import.** Spot-check a few patron records in Stagemgr to confirm their donor tiers updated correctly, especially for patrons matched by name rather than ID.

4. **Check the timestamp.** The `donor_tier_updated_on` field on customer records lets you quickly see whether a patron's donor data is current or stale.
