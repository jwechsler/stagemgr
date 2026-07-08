# Festival Reporting

!!! info "Who uses this?"
    **Box Office Managers** and **Administrators** run festival-wide reports. **Theater Users** see festival groups only for festivals whose productions belong to their theaters.

**Navigation:** Reports / Analysis -- festivals appear inside the production pickers

---

## Festivals in Production Pickers

Everywhere you search for a production -- report forms, analysis comparisons, imports -- the typeahead offers festival **group entries** alongside seasons, theaters, and tags. Type the festival's name and pick **"All shows in {Festival Name}"** to select every festival production at once instead of adding shows one by one.

Group selections respect your permissions: a Theater User expanding a festival group receives only the member productions from their own theaters.

## Festival Sales

The **Sales by Performance** report accepts multiple productions. Pick the festival group and the report covers every member show, performance by performance, and finishes with a **TOTAL** row aggregating the festival's full revenue and ticket counts. When all selected shows belong to one festival, the report is titled with the festival's name.

!!! note "Per-ticket-class breakdown"
    The per-class column breakdown is available for single-production reports only; multi-production (festival) runs report at the performance level with the aggregate TOTAL row.

## Festival Attendees

The **Production Attendee** report also accepts multiple productions, so one export covers the entire festival:

1. Go to **Reports** and find the attendee export.
2. In the production picker, choose **"All shows in {Festival Name}"** (individual shows can be added or removed after expanding the group).
3. Run the export. The CSV is emailed as usual.

Attendees are de-duplicated across the selected shows, and email opt-in status is merged. When every selected production shares one festival, the export file is named after the festival (for example `summer-shorts-festival-attendees-1.csv`); otherwise it is named `selected-productions`.

## Analysis

Festival groups work in the **Analysis** comparison pickers as well -- select the festival group to chart its shows' rate of sales side by side, exactly like any other hand-picked set of productions.
