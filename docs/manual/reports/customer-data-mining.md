# Mine Customer Data

!!! info "Roles: Admin Only"
    This report is restricted to **Administrators** under the **Mine Customer Data** permission group.

**Navigation:** Admin Menu > Reports > Mine Customer Data

---

## Purpose

The Mine Customer Data report builds a list of patrons who attended in a period, filtered by
how much they spent and how many productions they saw. It is the most flexible report in
Stagemgr for segmenting your customer base and building targeted outreach lists, and its
CSV uses the TRG Arts import layout so it drops straight into a TRG upload.

## Generating the Report

1. Navigate to **Admin Menu > Reports**.
2. In the **Mine Customer Data** section, set the criteria fields (see below).
3. Click **Download**. The report runs as a background job.
4. When processing completes, you receive an email with a download link. The report also
   appears in the **Generated Reports** section at the bottom of the Reports page.

!!! note "Background Job"
    This report always runs as a background job because it scans every patron with activity
    in the period. A wide-open run (a year back, no minimums) takes about a minute; narrower
    criteria finish in seconds.

## Who Is Included

Before any threshold is applied, a patron must have:

- a **Processed** or **Fulfilled** ticket order for a performance dated between the
  **Activity After** date and today,
- at least one non-complimentary ticket on that order (comp-only patrons are left out), and
- a street address on file (line 1 is not blank).

## Input Fields

| Field | Required | Description |
|---|---|---|
| **Activity After** | Yes | Start of the lookback window. Attendance, spending and the production count all run from this date through today. |
| **Min. Revenue** | No | Only include patrons whose settled payments processed since the Activity After date total at least this dollar amount. Only orders the patron bought count; gift tickets bought for them by someone else do not. `0` applies no filter. |
| **Min. Perf.** | No | Only include patrons who attended at least this many distinct **productions** in the window (the same number the `AttendedInPeriod` column reports). Two performances of the same show count once. `0` applies no filter. |
| **Must have attended** | No | Only include patrons whose attendance in the window includes a production by one of the selected theaters. Select one or more; leave empty for no filter. |

### How Criteria Combine

All criteria are applied together using AND logic. A patron must satisfy every criterion you
set to appear in the results. For example:

- **Activity After** = January 1, 2025 + **Min. Revenue** = $200 + **Min. Perf.** = 3

returns only patrons who, since January 1, 2025, have paid at least $200 AND attended at
least 3 different productions.

!!! tip "Start Broad, Then Narrow"
    If you are unsure what thresholds to use, start with an early date and zero minimums.
    Review the results, then re-run with tighter criteria to refine your list.

## Output Format

The CSV starts with the standard TRG Arts import columns, then adds the report's own.
Email addresses are **not** exported by this report; the `Email` column is blank.

| Column | Value |
|---|---|
| **Segment** | `LST` for every row |
| **Season**, **Title** | Blank |
| **FirstName**, **LastName**, **FullName** | Patron name |
| **CompanyName**, **Address3**, **BusinessPhone** | Blank |
| **Email** | Blank (not exported) |
| **Address1**, **Address2**, **City**, **State**, **Zip** | Mailing address |
| **HomePhone** | Phone number |
| **ClientPatronID** | The patron's id in your external system, if tagged for one of your theaters |
| **StagemgrPatronID** | The patron's Stagemgr customer id |
| **PrimaryTheatreAttendee** | `*` when the patron has ever attended a producing (in-house) theater |
| **LastAttended** | Date of the patron's most recent performance, any status |
| **AttendedInPeriod** | Distinct productions attended in the window |
| **TotalAttended** | Distinct productions attended, all time |
| **CompaniesAttendedInPeriod** | Distinct theaters attended in the window |
| **TotalCompaniesAttended** | Distinct theaters attended, all time |
| **ProductionHistory** | Names of the productions attended in the window, alphabetical, comma-separated |
| **IsMember** | `Y` when the patron holds an active membership |
| **IsFlexPassHolder** | `Y` when the patron holds an active FlexPass |

## Typical Use Cases

- **Major donor prospecting**: Identify patrons with high spending and frequent attendance as
  candidates for fundraising outreach.
- **VIP programs**: Build lists of top patrons for exclusive invitations and early access offers.
- **Cross-venue marketing**: Find patrons who attend shows at one theater but not another,
  and target them with cross-promotional offers.
- **Lapsed patron recovery**: Set the Activity After date far back and a high production
  count to find previously active patrons who may have stopped attending.
- **Season ticket campaigns**: Identify frequent attendees who might benefit from a FlexPass
  or membership offering.

## Tips

- The **Must have attended** field is useful when your organization hosts multiple companies.
  Use it to find patrons loyal to a specific theater or to identify cross-venue attendees.
- Leave the minimums at `0` to apply no filter for that criterion.
- There is no end date; the window always runs from the **Activity After** date through today.
- Results are delivered as a CSV that can be uploaded to TRG Arts or opened in a spreadsheet.

!!! warning "Admin Only"
    This report provides access to comprehensive customer data across all theaters. It is
    restricted to administrators to prevent unauthorized access to sensitive patron information.

## Related Pages

- [Reports Overview](reports-overview.md)
- [Production Attendees](production-attendees.md)
- [TRG Exports](trg-exports.md)
