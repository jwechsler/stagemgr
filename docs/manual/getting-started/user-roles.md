# User Roles & Permissions

Stagemgr uses a three-tier role system. Every staff user is assigned exactly one role, which determines what they can see and do in the system. Roles are set when creating a user account under **Options > Administer Users**.

## Role Overview

| Role | Internal Name | Access Level |
|------|--------------|-------------|
| **Administrator** | Administrator | Full access to all features and all theaters |
| **Box Office** | Box Office | Day-to-day operations across all active theaters |
| **Theater User** | Producer | Limited access scoped to assigned theaters only |

A user who is neither Administrator nor Box Office is automatically a Theater User. Theater Users must be assigned to one or more specific theaters to see any data.

### Administrator

Administrators have unrestricted access to every feature in Stagemgr. This role is intended for system managers who need to:

- Create, edit, and delete theaters, productions, and all related records
- Manage staff user accounts
- Configure system-wide settings (default ticket classes, payment types)
- Merge duplicate patron records
- Delete orders and seat maps
- Manage membership offers
- Access all reports, including Customer Data Mining
- Refund donation orders

### Box Office

Box Office staff can handle all day-to-day ticketing and customer operations across all active theaters. This role is intended for front-of-house staff who need to:

- Create and manage all order types (ticket, donation, flex pass, membership)
- Process payments, exchanges, refunds, and order splits
- Create and edit productions and performances
- Manage ticket classes, special offers, and performance features
- Fulfill and unclaim orders
- Access box office reports, house management reports, and reconciliation reports
- Import data (mailing cards, bulk orders, external contacts, etc.)
- Create and manage venues, seat maps, and service items

**Box Office staff cannot:**

- Delete productions, seat maps, or orders
- Manage user accounts
- Manage payment types
- Merge patron records
- Configure system-wide settings (default ticket classes)
- Access Customer Data Mining report
- Refund donation orders

### Theater User

Theater Users have the most restricted access, limited to theaters they are explicitly assigned to. This role is intended for visiting companies, guest artists, and external producers who need to:

- View productions and performances for their assigned theaters
- Create and manage ticket orders for their theaters' productions
- View orders related to their theaters
- Create and edit patron records
- Add notes to orders
- View basic reports (Production Sales, Production Attendees, Order Dump, TRG Dump, Donation Dump)
- Place hold orders (with allowed payment types)

**Theater Users cannot:**

- View or manage data from other theaters
- Process exchanges, refunds, or order splits
- Create or edit productions or performances
- Manage ticket classes, special offers, or pricing
- Fulfill orders or run house management operations
- Access box office, reconciliation, or membership reports
- Import data

#### Resident Company Theater Users

Theater Users assigned to a **Resident Company** theater receive one additional permission: they can **view patron email addresses** in reports and record views. Non-resident Theater Users only see email addresses for patrons who have explicitly opted into the theater's email marketing list.

## Permissions by Feature Area

### Theaters & Productions

| Action | Administrator | Box Office | Theater User |
|--------|:---:|:---:|:---:|
| View theaters | All | All active | Assigned only |
| Create/edit theater | Yes | Yes | No |
| Delete theater | Yes | No | No |
| Create/edit production | Yes | Yes | No |
| Delete production | Yes | No | No |
| Create/edit performance | Yes | Yes | No |
| Duplicate performance | Yes | Yes | No |
| Delete performance | Yes | Yes | No |

### Orders

| Action | Administrator | Box Office | Theater User |
|--------|:---:|:---:|:---:|
| Create ticket order | Yes | Yes | Yes |
| View orders | All | All | Own theaters |
| Edit/update orders | Yes | Yes | Notes only |
| Hold orders | Yes | Yes | Yes |
| Process payments | Yes | Yes | Limited |
| Fulfill/unclaim orders | Yes | Yes | No |
| Exchange orders | Yes | Yes | No |
| Refund ticket orders | Yes | Yes | No |
| Refund donation orders | Yes | No | No |
| Split orders | Yes | Yes | No |
| Convert to donation | Yes | Yes | No |
| Cancel orders | Yes | Yes | No |
| Delete orders | Yes | No | No |
| Resend confirmation | Yes | Yes | No |
| Reprint tickets | Yes | Yes | No |

### Customers

| Action | Administrator | Box Office | Theater User |
|--------|:---:|:---:|:---:|
| View patrons | All | All | Own theaters' customers |
| Create/edit patrons | Yes | Yes | Yes |
| View email addresses | Yes | Yes | Opted-in only* |
| Merge duplicates | Yes | No | No |
| Manage tags | Yes | Yes | Yes |

*Resident Company Theater Users can view all email addresses.

### Reports

| Action | Administrator | Box Office | Theater User |
|--------|:---:|:---:|:---:|
| Production Sales by Performance | Yes | Yes | Yes |
| Production Attendees | Yes | Yes | Yes |
| Order Dump | Yes | Yes | Yes |
| TRG Dump | Yes | Yes | Yes |
| Donation Dump | Yes | Yes | Yes |
| Weekly Box Office | Yes | Yes | No |
| Flex Pass Sales | Yes | Yes | No |
| Daily Box Office Receipts | Yes | Yes | No |
| Fulfill Tickets | Yes | Yes | No |
| Donations Total | Yes | Yes | No |
| Membership Export | Yes | Yes | No |
| Flex Pass Patron Report | Yes | Yes | No |
| Attended Dump | Yes | Yes | No |
| House Management Seating | Yes | Yes | No |
| Membership Usage | Yes | Yes | No |
| Mine Customer Data | Yes | No | No |

### System Configuration

| Action | Administrator | Box Office | Theater User |
|--------|:---:|:---:|:---:|
| Manage users | Yes | No | No |
| Manage payment types | Yes | No | No |
| Default ticket classes | Yes | No | No |
| Special offers | Yes | Yes | No |
| Performance features | Yes | Yes | No |
| Service items | Yes | Yes | No |
| Venues | Yes | Yes | No |
| Seat maps (create/edit) | Yes | Yes | No |
| Seat maps (delete) | Yes | No | No |
| Import data | Yes | Yes | No |
| View system options | Yes | Yes | No |
| Manage system options | Yes | No | No |

## Theater Assignment

Theater Users must be assigned to one or more theaters to have any access. Administrators and Box Office staff automatically see all active theaters, regardless of theater assignment.

To assign theaters to a user, go to **Options > Administer Users**, edit the user, and select the theaters they should have access to.

## Data Visibility Rules

The role system affects what data users can see:

- **Theater Users** see only orders, productions, performances, and patron records associated with their assigned theaters.
- **Box Office and Administrators** see data across all active theaters.
- **Patron email addresses** are filtered based on role and email opt-in status (see [Customers](../customers/managing-patrons.md) for details).
- **Reports** are filtered by role -- some reports are only visible to Box Office and above, and Customer Data Mining is Administrator-only.
