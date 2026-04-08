# Permissions Matrix

!!! info "Reference"
    Complete permissions reference organized by feature area. Permissions are cumulative -- each higher role includes all permissions of lower roles.

## Role Hierarchy

Stagemgr has three staff roles, each building on the permissions of the role below it:

| Role | Description |
|------|-------------|
| **Theater User** | External theater staff with limited access to their own theater's data |
| **Box Office** | Internal staff with full day-to-day operational access |
| **Administrator** | Full system access including configuration and destructive operations |

!!! note "Resident Company Users"
    Theater Users who are marked as **resident company** members receive expanded email access permissions equivalent to Box Office staff. All other Theater User restrictions still apply.

## Theaters and Venues

| Action | Administrator | Box Office | Theater User |
|--------|:---:|:---:|:---:|
| View theaters | Yes | Yes | Own theaters only |
| Create/edit theaters | Yes | Yes | -- |
| Delete theaters | Yes | -- | -- |
| Create/edit venues | Yes | Yes | -- |
| Create/edit seat maps | Yes | Yes | -- |
| Delete seat maps | Yes | -- | -- |

## Productions

| Action | Administrator | Box Office | Theater User |
|--------|:---:|:---:|:---:|
| View productions | Yes | Yes | Own theaters only |
| Create productions | Yes | Yes | -- |
| Edit productions | Yes | Yes | -- |
| Duplicate productions | Yes | Yes | -- |
| Delete productions | Yes | -- | -- |
| Send sample confirmation email | Yes | Yes | -- |
| Send sample follow-up email | Yes | Yes | -- |
| Auto-complete production search | Yes | Yes | Yes |

## Performances

| Action | Administrator | Box Office | Theater User |
|--------|:---:|:---:|:---:|
| View performances | Yes | Yes | Yes |
| Create performances | Yes | Yes | -- |
| Edit performances | Yes | Yes | -- |
| Duplicate performances | Yes | Yes | -- |
| Delete performances | Yes | Yes | -- |
| Release held seats | Yes | Yes | -- |
| Email attendees (broadcast) | Yes | Yes | -- |

## Ticket Classes and Allocations

| Action | Administrator | Box Office | Theater User |
|--------|:---:|:---:|:---:|
| View ticket class allocations | Yes | Yes | Yes (backend classes) |
| Manage ticket classes | Yes | Yes | -- |
| Manage default ticket classes | Yes | -- | -- |

## Orders

| Action | Administrator | Box Office | Theater User |
|--------|:---:|:---:|:---:|
| View ticket orders | Yes | Yes | Yes (read only) |
| Create ticket orders | Yes | Yes | Yes |
| Edit/update ticket orders | Yes | Yes | -- |
| Cancel orders | Yes | Yes | -- |
| Refund orders | Yes | Yes | -- |
| Refund donation orders | Yes | -- | -- |
| Delete orders | Yes | -- | -- |
| Exchange tickets | Yes | Yes | -- |
| Split orders | Yes | Yes | -- |
| Convert to donation | Yes | Yes | -- |
| Hold orders | Yes | Yes | -- |
| Mark unclaimed | Yes | Yes | -- |
| Resend confirmation | Yes | Yes | -- |
| Fulfill orders | Yes | Yes | -- |
| Sell past performances | Yes | Yes | -- |
| Order anytime | Yes | Yes | -- |
| Process season seating orders | Yes | Yes | -- |
| Prehold season seating | Yes | Yes | Yes |
| Update order notes | Yes | Yes | Yes |
| Swipe card payment | Yes | Yes | -- |
| Modify service items | Yes | Yes | -- |

## Donations, Flex Passes, and Memberships

| Action | Administrator | Box Office | Theater User |
|--------|:---:|:---:|:---:|
| View donation orders | Yes | Yes | Yes (read only) |
| Create/edit donation orders | Yes | Yes | -- |
| Refund/delete donation orders | Yes | -- | -- |
| View/create/edit flex pass orders | Yes | Yes | -- |
| Cancel/fulfill flex pass orders | Yes | Yes | -- |
| Delete flex pass orders | Yes | -- | -- |
| View/manage flex pass offers | Yes | Yes | Own theaters only |
| View/create membership orders | Yes | Yes | -- |
| Cancel/reactivate/fulfill memberships | Yes | Yes | -- |
| Delete membership orders | Yes | -- | -- |
| Edit membership offers | Yes | Yes | Own theaters only |
| Manage membership offers (full) | Yes | -- | -- |

## Customers

| Action | Administrator | Box Office | Theater User |
|--------|:---:|:---:|:---:|
| View customers | Yes | Yes (all) | Own theater's customers |
| Create/edit customers | Yes | Yes | Yes |
| View email addresses | Yes | Yes | Opted-in only* |
| Merge customer records | Yes | -- | -- |
| Auto-complete customer search | Yes | Yes | Yes |

*Resident company Theater Users can view all email addresses.

## Special Offers and Features

| Action | Administrator | Box Office | Theater User |
|--------|:---:|:---:|:---:|
| Manage special offers | Yes | Yes | -- |
| Manage special features | Yes | Yes | -- |
| Manage service item templates | Yes | Yes | -- |

## Reports

| Action | Administrator | Box Office | Theater User |
|--------|:---:|:---:|:---:|
| View reports page | Yes | Yes | Yes (limited) |
| Box office reports | Yes | Yes | -- |
| House management reports | Yes | Yes | -- |
| Membership reports | Yes | Yes | -- |
| Reconciliation reports | Yes | Yes | -- |
| Show reports (TRG, donations, sales) | Yes | Yes | Yes |
| Fulfill donations report | Yes | -- | -- |
| Customer data mining | Yes | -- | -- |

## Analysis

| Action | Administrator | Box Office | Theater User |
|--------|:---:|:---:|:---:|
| Access analysis section | Yes | -- | Yes (own theaters) |
| Search all productions | Yes | -- | Own theaters only |
| Search group shortcuts (season/theater) | Yes | -- | Own theaters only |
| Run rate of sales analysis | Yes | -- | Yes (own theaters) |
| Revenue projection and extensions | Yes | -- | Yes (own theaters) |

## Imports, System Configuration, and Payments

| Action | Administrator | Box Office | Theater User |
|--------|:---:|:---:|:---:|
| Access import operations | Yes | Yes | -- |
| View system options | Yes | Yes | -- |
| Manage system options | Yes | -- | -- |
| View/confirm credit card payments | Yes | Yes | -- |
| Manage payment types | Yes | -- | -- |
| Manage users | Yes | -- | -- |
