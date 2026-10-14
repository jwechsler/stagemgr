# Donor Levels Import (LGL)

!!! info "Required Role"
    **Administrator** or **Box Office** can run a donor levels import from the
    Imports page. Setting up the nightly import needs an administrator.

**Navigation:** Options > Imports > Donor Levels Import

## Purpose

This import sets each customer's **donor tiers** (the current and previous
fiscal year) from the giving levels Little Green Light (LGL) calculates. Box
office and house management staff then see a patron's giving level alongside
their ticketing record, on the customer page and in the House Management
report.

The import runs in two ways, with the same file and the same rules:

1. **Automatically every night**, from a saved report in LGL.
2. **By hand**, by uploading the report on **Options > Imports**.

---

## The Nightly Import

Each night at 4:30 Stagemgr downloads the saved report from LGL and imports
it. It runs whenever the report link is configured, whether or not
[LGL sync](../customers/lgl-sync.md) is turned on.

### Setting It Up

1. **Build the report in LGL.** Create a constituent export that includes the
   columns `External constituent ID`, `LGL Constituent ID`,
   `TG Tier Last Fiscal` and `TG Tier This Fiscal`. Other columns, such as `First Name`, `Last Name`,
   `Pref. Email` and `Address 1` / `Address 2` / `Address 3`, may be included;
   Stagemgr ignores them and carries them through to the result file
   untouched. Make the report cover **every** constituent with a giving
   level (see [How It Works](#how-it-works)).
2. **Create a permanent link** for the saved report in LGL.
3. **Give the link to your administrator**, who stores it in Stagemgr's
   configuration as `littlegreenlight.donor_tier_report_url`. If opening the
   link asks for an LGL login, the administrator also stores an LGL web user
   name and password as `LGL_USER` and `LGL_PASSWORD`.

The results are emailed to the Stagemgr user whose email is the
supervisor-notifications address. The
[LGL Sync status page](../customers/lgl-sync.md#donor-tiers) shows whether the
report is on, who receives the results, and when the report was last
downloaded and imported. Its **Fetch donor levels now** button runs the
download and import straight away.

!!! note "When the download fails"
    If Stagemgr cannot download the report (a wrong link, a rejected login, or
    a file without the three required columns), nothing is imported and every
    customer keeps their current tiers. The **Last report download** time on
    the LGL Sync page stops advancing; tell your administrator.

---

## Uploading by Hand

On **Options > Imports**, choose **Donor Levels Import** and upload the CSV
exported from the same LGL report. There is no theater or production to
select. The upload follows exactly the same rules as the nightly import,
including clearing the tiers of customers who are not in the file.

## Required CSV Headers

| Header | Description |
|--------|-------------|
| `External constituent ID` | The Stagemgr customer number. LGL sync keeps this set on every linked constituent |
| `TG Tier Last Fiscal` | Donor tier for the previous fiscal year |
| `TG Tier This Fiscal` | Donor tier for the current fiscal year |

An optional `LGL Constituent ID` column (the constituent's LGL id) lets a row
with a blank `External constituent ID` be matched through the customer's
LGL ID tag; see [How It Works](#how-it-works).

Header names are matched regardless of capitals, but the spaces must be
there. If any of the three required headers is missing, the import stops before changing
anything; the Imports page shows `Donor levels import failed: missing column`
and the column's name.

---

## How It Works

- **Matching is by customer number, then by LGL id.** A row's
  `External constituent ID` must be a Stagemgr customer number. When it is
  blank, the row's `LGL Constituent ID` is matched against the customers'
  LGL ID tags. A customer number that matches no one is an error; the LGL id
  is not tried. Names and emails in the file are never used to find a
  customer.
- **The import only sets tiers.** It never creates, merges or renames
  customers, and never changes any other field.
- **Blank tier cells clear the tier.** A matched row with an empty
  `TG Tier This Fiscal` leaves that customer with no current-year tier.
- **The file is the complete list of current donors.** After the whole file
  has loaded, every customer who has a tier but is not in the file has both
  tiers cleared.

!!! warning "Upload complete files only"
    Because customers missing from the file lose their tiers, uploading a
    partial file (one fund, one campaign, a filtered list) clears everyone
    else. If that happens, run the import again with the complete report; the
    tiers come back.

---

## Result File

When some rows could not be applied, Stagemgr writes a result file
(`donor_import_results_<your-file-name>.csv`) listing only the rows that have
an entry in the `Error` column, with the file's own columns plus `Error`. When
no row has an error, there is no result file. See
[Result File](imports-overview.md#result-file) for the naming rules.

| Row | `Error` |
|---|---|
| `External constituent ID` is not a number | `External constituent ID is not a number` |
| No customer has that number | `No customer with this External constituent ID` |
| Blank customer number, and several customers carry the row's LGL ID tag | `LGL Constituent ID is on customers 123, 456: merge them` |
| The customer could not be saved | The reason it failed |

Matched rows (including those matched by LGL id) and rows with a blank
`External constituent ID` whose LGL id is on no customer (organisations, and
constituents not yet in Stagemgr) are counted but not listed. Organisations
never become Stagemgr customers, so they are always counted this way.

### Completion Email

Every time the import finishes, Stagemgr emails the person who uploaded the
file (for the nightly import, the supervisor-notifications user) with the
file name and its counts: constituents in the file, customer records updated
and update errors, then unchanged rows, rows without an
`External constituent ID`, rows matched by `LGL Constituent ID`, and customers
cleared because they were not in the
file. When there is a result file it is attached; otherwise the email says no
rows had errors.

The Imports page shows a summary line for each run, for example:

```text
Donor levels: 1250 rows; updated 40, unchanged 1150, cleared 3, matched by LGL ID 12, no id 43, errors 2; cleared 6 absent customers
```

| Count | Meaning |
|---|---|
| updated | Matched customers whose tiers changed |
| unchanged | Matched customers whose tiers were already correct |
| cleared | Matched customers whose row had both tiers blank |
| matched by LGL ID | Rows with a blank `External constituent ID` matched through a customer's LGL ID tag (also counted as updated, unchanged or cleared) |
| no id | Rows with a blank `External constituent ID` that no LGL ID tag resolved |
| errors | Rows with an entry in the Error column: a number that matches no customer, an id that is not a number, an LGL id on several customers, or a row that could not be saved |
| absent customers | Customers with a tier who were not in the file and had both tiers cleared |

---

## Where Donor Tiers Appear

| Feature | Usage |
|---------|-------|
| **Customer page** | A **Donor Level** box above the productions attended shows the current and previous fiscal year's tiers ("none" for a year without one); it appears only when either tier is set |
| **[House Management Report](../house-management/house-management-report.md)** | The donor level appears beside the patron's name, and donors are listed even when nothing else would include them |

---

## Example CSV

```csv
External constituent ID,LGL Constituent ID,First Name,Last Name,Pref. Email,TG Tier Last Fiscal,TG Tier This Fiscal
4523,900101,Jane,Smith,jane@example.com,Gold,Platinum
7810,900102,Michael,Chen,mchen@example.com,,Silver
3302,900103,Sarah,Johnson,sarah@example.com,,
,900104,Ana,Lopez,ana@example.com,Silver,Gold
,900105,,Example Foundation,grants@example.org,Gold,Gold
```

In this example:

- Customer 4523 (Jane Smith) gets Gold last year and Platinum this year.
- Customer 7810 (Michael Chen) has no tier last year and Silver this year.
- Customer 3302 (Sarah Johnson) has both tiers cleared.
- Ana Lopez has no customer number in LGL; the customer tagged LGL ID 900104
  gets Silver last year and Gold this year.
- Example Foundation is an organisation with no customer number, and no
  customer carries its LGL id. It is counted as a row without an id, is not listed in the result file, and
  changes nothing.
- Every other customer who has a tier has both tiers cleared, because they
  are not in the file.

---

## Best Practices

1. **Keep the LGL report complete.** It must list every constituent who has a
   giving level. Do not add filters that leave donors out, or those donors
   lose their tiers in Stagemgr the next night.

2. **Check the LGL Sync page.** The **Last report download** and
   **Last donor levels import** rows show whether the nightly import is
   running. If the dates stop advancing, tell your administrator.

3. **Read the completion email.** It arrives after every import. When it
   reports update errors, open the attached result file. A row with no
   matching customer usually means the constituent's
   `External constituent ID` in LGL is wrong; correct it in LGL.
