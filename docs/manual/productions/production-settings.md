# Production Settings

!!! info "Required Role"
    **Administrator** or **Box Office** can change production status and class. Only **Administrators** can set a production to **Season Seating** status.

**Navigation:** Productions > [Production Name] > Edit

## Production Status

The status field is the primary control for a production's visibility, sales behavior, and administrative workflow. Each status has distinct effects on the public website, box office operations, and patron communications.

### Active

The default operational status for a production that is on sale.

- **Website:** Production appears in the public calendar, production listings, and search results.
- **Sales:** Patrons can purchase tickets online. Box office staff can process orders.
- **Communications:** Confirmation and follow-up emails are sent normally.
- **Run dates required:** Opening, closing, press opening, and first preview dates must be set.

### Presale

Used for productions that should be visible on the website but are not yet available for purchase.

- **Website:** Production appears in the calendar and listings with run dates and descriptions, but no purchase links are shown.
- **Sales:** Online ticket sales are blocked. Box office staff can still create orders manually if needed.
- **Communications:** Standard emails are sent for any manually created orders.
- **Run dates required:** Yes, same as Active.

!!! tip "Presale to Active"
    Use Presale to build anticipation. When you are ready to open sales, simply change the status to Active. No other changes are needed -- performances and ticket classes should already be configured.

### Private

Hides the production from the public website entirely, but it remains fully functional for internal use.

- **Website:** Production does not appear in any public listing, calendar, or search result.
- **Sales:** Online purchase is possible only via direct URL. Box office staff can process orders normally.
- **Communications:** Emails are sent normally for any orders placed.
- **Run dates:** Not required (but recommended for reporting).

!!! tip "When to Use Private"
    Private is useful for invite-only events, industry performances, private rentals, or soft launches where you want to distribute a direct link to a limited audience.

### Inactive

Fully removes the production from both public and most administrative views. This is the status for productions that are no longer running.

- **Website:** Production is completely hidden.
- **Sales:** No new orders can be placed online or via box office.
- **Communications:** No new emails are generated. Existing order records remain accessible.
- **Run dates:** Not required.

!!! warning "Deactivating a Production"
    Setting a production to Inactive does not cancel or refund existing orders. Always process outstanding orders before deactivating.

### Season Seating

A specialized workflow for subscriber seating assignments. This status fundamentally changes how orders are processed.

- **Website:** Production is not publicly visible.
- **Sales:** Orders can be created (typically via bulk import) but are placed **on hold** instead of being processed immediately.
- **Communications:** Patron notification emails are suppressed while in this status.
- **Access:** Only **Administrators** can create and manage orders.
- **Transition behavior:** When the status is changed away from Season Seating, a background job (FinalizeSeasonSeating) processes all held orders and sends notifications to subscribers.

See [Season Seating](season-seating.md) for a complete walkthrough of this workflow.

## Production Class

Production class categorizes the type of event. It primarily affects reporting and how the production is grouped or filtered in administrative views. Unlike status, it does not directly control visibility or sales behavior.

### Primetime

The default class for main stage productions. These are the theater's primary programming and receive the most prominent placement in reports and dashboards.

### Special Event

For galas, fundraisers, benefit performances, or other one-off events that are not part of the regular season. Reported separately from main stage programming.

### Private Party

For venue rentals, corporate events, or private bookings. Typically paired with Private status, though this is not enforced.

### Conference

For meetings, conferences, symposiums, or multi-session events held at the venue.

### Off/Late Night

For secondary programming such as late-night shows, cabarets, or after-hours events. Helps distinguish these from the main stage season in reports.

### Class

For educational programming -- workshops, masterclasses, acting classes, or youth programs.

### External

For events that are managed or ticketed outside of Stagemgr but tracked in the system for reporting or scheduling purposes.

## How Status and Class Interact

Status and class are independent settings. Any class can be combined with any status. However, some combinations are more common than others:

| Combination | Typical Use |
|------------|------------|
| Active + Primetime | Standard on-sale main stage show |
| Presale + Primetime | Upcoming show, announced but not yet on sale |
| Private + Private Party | Venue rental, hidden from public |
| Private + Special Event | Invite-only gala with direct-link ticket purchase |
| Inactive + any class | Closed or archived production |
| Season Seating + Primetime | Subscriber seat selection period for a main stage show |

## Changing Status

When changing a production's status, be aware of these behaviors:

1. **Moving to Active or Presale:** Stagemgr validates that all four run dates (opening, closing, press opening, first preview) are set. The save will fail if any are missing.

2. **Moving away from Season Seating:** Triggers the FinalizeSeasonSeating background job, which processes all held orders and sends patron notifications. This action cannot be undone.

3. **Moving to Inactive:** The production disappears from most admin views. Use the "Show Inactive" filter to find it again if needed.

!!! warning "Status Changes Are Immediate"
    Changing status takes effect as soon as you save. If you change a production from Presale to Active, tickets go on sale immediately. Plan your timing accordingly.
