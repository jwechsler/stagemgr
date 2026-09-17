# Managing Memberships

!!! info "Access"
    The Memberships list is available to **Admin** and **Box Office** users only. Theater users do not see the Passes > Memberships menu entry.

**Navigation:** Passes > Memberships

---

## Overview

The Memberships list shows every individual membership in the system -- one row per membership record -- with live search, sorting, and paging. Use it to look up a member by name or member code, check whether a membership is still active, and see when it started and ended.

![Memberships list showing member code, offer, member, status, start, and membership end columns](../assets/images/screenshots/memberships-list.png)

## Columns

| Column | Description |
|--------|-------------|
| **Member Code** | The membership's unique code. Click it to open the membership detail page. |
| **Offer** | The [membership offer](../offers/membership-offers.md) the membership was purchased or issued under, with its type (`production` or `timed`) in parentheses. |
| **Member** | The patron's name. Searching by first or last name matches this column. |
| **Status** | `Active`, `Suspended`, `Canceled`, `Pending`, or `Expired`. |
| **Start** | When the membership began -- the billing subscription's start date when one exists, otherwise the date the membership record was created. |
| **Membership End** | When the membership ended or will end. See below. |

### How Membership End is determined

- For canceled or expired memberships, this is the date the membership actually closed.
- For an active membership scheduled to cancel at the end of its billing period, the final billing date is shown with a **Cancel pending** label.
- A blank value means the membership is ongoing with no scheduled end.

## Sorting and Searching

- **Default order** puts memberships in status priority -- Active first, then Suspended, then Canceled -- with members alphabetical within each status.
- Click any column header to sort by that column instead; click again to reverse.
- The **Search** box matches member codes (by prefix), member first/last names, offer names, and statuses, narrowing as you type.
- Paging and your last search are remembered between visits.

!!! tip "Finding one member quickly"
    Type the first few characters of the member code (e.g. `TW-RM`) or the member's last name. The list filters server-side, so it stays fast no matter how many memberships exist.

## Row Actions

| Action | What it does |
|--------|--------------|
| **Member Code link** | Opens the membership's detail page. |
| **Edit** | Opens the membership's edit form (status, member since, preferred seating). |

The detail page also offers **Generate Member ID Card**; see
[below](#generating-a-member-id-card).

## Generating a Member ID Card

A membership's detail page (open it from the Member Code link) has a
**Generate Member ID Card** button when the membership's offer has card artwork
uploaded (see [Membership Offers -- Member ID Card Artwork](../offers/membership-offers.md#member-id-card-artwork)).
Clicking it downloads a PNG named after the member code, for example
`member-card-tw-abc123.png`, ready to print on a CR-80 card printer.

The card shows four things from the record:

| On the card | Comes from |
|-------------|------------|
| Photo | The patron's photo on their [address record](../customers/managing-patrons.md). Without one the card prints with the background showing through the photo panel. Square-ish, face near the middle, at least 400 px on the short side prints best. |
| Name | The address's full name, as stored. Long names shrink and wrap onto two lines automatically. |
| Member number | The member code, printed exactly as shown. |
| Since | The year this patron *first* became a member, across all of their memberships -- a patron who lapsed and rejoined keeps their original year. |

!!! tip "Printing"
    The PNG is tagged 300 dpi. Print at 100%, never "fit to page": the artwork
    already allows for the printer's unprinted edge.

If the offer has no card background, the detail page shows a note instead of
the button, with a link to the offer's edit form for administrators.

## Creating a Membership

The **New Membership** button below the list creates a membership record directly -- without a purchase order. This is how staff issue shared [library passes](../offers/membership-offers.md) and complimentary memberships. For a paid membership, use **Create Order** on the [Membership Offers list](../offers/membership-offers.md#the-membership-offers-list) instead so billing is set up.

!!! note "Email list sync"
    When a membership becomes Active, the member's address is automatically added to the offer's MyEmma email group (if one is configured); when it is canceled, the address is removed -- unless the patron still holds another current membership. The sync runs as a background job. See [Membership Offers -- Email Integration](../offers/membership-offers.md#email-integration).

## Related Pages

- [Membership Offers](../offers/membership-offers.md)
- [Membership Orders](membership-orders.md)
- [Membership Reports](../reports/membership-reports.md)
