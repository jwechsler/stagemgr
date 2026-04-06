# Mine Customer Data

!!! info "Roles: Admin Only"
    This report is restricted to **Administrators** under the **Mine Customer Data** permission group.

**Navigation:** Admin Menu > Reports > Mine Customer Data

---

## Purpose

The Mine Customer Data report identifies high-value patrons based on customizable criteria
including activity dates, minimum revenue thresholds, attendance frequency, and theater
affiliations. It is the most flexible report in Stagemgr for segmenting your customer base
and building targeted outreach lists.

## Generating the Report

1. Navigate to **Admin Menu > Reports**.
2. In the **Mine Customer Data** section, configure the criteria fields (see below).
3. Click **Generate**. The report runs as a background job.
4. When processing completes, you will receive an email with a download link. The report also
   appears in the **Generated Reports** section at the bottom of the Reports page.

!!! note "Background Job"
    This report always runs as a background job due to the potentially large dataset it must
    scan. Processing time varies depending on the breadth of your criteria. Narrower criteria
    (shorter date range, higher thresholds) will process faster.

## Input Fields

| Field | Required | Description |
|---|---|---|
| **Activity Date** | Yes | Only consider customer activity on or after this date. This defines the lookback window for all other criteria. |
| **Minimum Revenue** | No | Only include customers whose total spending meets or exceeds this dollar amount within the activity window. |
| **Minimum Performances** | No | Only include customers who attended at least this many distinct performances within the activity window. |
| **Required Theaters** | No | Only include customers who have purchased tickets at the selected theater(s). Select one or more theaters from the list. |

### How Criteria Combine

All specified criteria are applied together using AND logic. A customer must satisfy every
criterion you set to appear in the results. For example:

- **Activity Date** = January 1, 2025 + **Minimum Revenue** = $200 + **Minimum Performances** = 3

This would return only customers who, since January 1, 2025, have spent at least $200 AND
attended at least 3 performances.

!!! tip "Start Broad, Then Narrow"
    If you are unsure what thresholds to use, start with a broad date range and low minimums.
    Review the results, then re-run with tighter criteria to refine your list.

## Output Format

The report generates a CSV file containing matching customer records:

| Column | Description |
|---|---|
| **Customer Name** | Full name |
| **Email** | Email address |
| **Phone** | Phone number |
| **Address** | Mailing address |
| **Total Revenue** | Total spending within the activity window |
| **Performance Count** | Number of distinct performances attended |
| **Theaters** | Theaters where the customer has purchased tickets |
| **Last Activity** | Date of the customer's most recent order |

## Typical Use Cases

- **Major donor prospecting**: Identify patrons with high spending and frequent attendance as
  candidates for fundraising outreach.
- **VIP programs**: Build lists of top patrons for exclusive invitations and early access offers.
- **Cross-venue marketing**: Find customers who attend shows at one theater but not another,
  and target them with cross-promotional offers.
- **Lapsed patron recovery**: Set the activity date far back and a high minimum performance
  count to find previously active patrons who may have stopped attending.
- **Season ticket campaigns**: Identify frequent attendees who might benefit from a FlexPass
  or membership offering.

## Tips

- The **Required Theaters** field is useful when your organization operates multiple venues.
  Use it to find patrons loyal to a specific theater or to identify cross-venue attendees.
- Leave optional fields blank to apply no filter for that criterion. For example, omitting
  **Minimum Revenue** includes customers at all spending levels.
- The **Activity Date** field defines the start of the lookback window. There is no end date;
  the system includes all activity from the specified date through the present.
- Results are delivered as a CSV that can be imported into email marketing platforms, CRM
  systems, or spreadsheet applications.

!!! warning "Admin Only"
    This report provides access to comprehensive customer data across all theaters. It is
    restricted to administrators to prevent unauthorized access to sensitive patron information.

## Related Pages

- [Reports Overview](reports-overview.md)
- [Production Attendees](production-attendees.md)
- [TRG Exports](trg-exports.md)
