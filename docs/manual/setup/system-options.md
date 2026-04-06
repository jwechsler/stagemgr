# System Options

!!! info "Required Role"
    **Administrators** can access all system options. **Box Office** staff can view system options and access Special Offers and Import Data.

**Navigation:** Options menu (main navigation)

## Overview

The Options menu provides access to all system-wide configuration. It is organized into two sections:

### Direct Menu Items

| Menu Item | Description | Who Can Access |
|-----------|-------------|---------------|
| **Special Offers** | Create and manage promotional discount codes | Administrator, Box Office |
| **Import data** | Bulk import tools for orders, contacts, and mailing lists | Administrator, Box Office |

### System Config Section

| Menu Item | Description | Who Can Access |
|-----------|-------------|---------------|
| **Administer Users** | Create and manage staff user accounts | Administrator only |
| **Performance Features** | Define special performance tags (e.g., "Opening Night", "ASL Interpreted") | Administrator, Box Office |
| **Default Ticket Classes** | Template ticket classes auto-applied to new productions | Administrator only |
| **Manage Payment Types** | Configure payment methods and their permissions | Administrator only |
| **Venues** | Create and manage physical performance spaces | Administrator, Box Office |
| **Service Items** | Define fee templates for orders and exchanges | Administrator, Box Office |
| **Job Queue** | Monitor background job processing (Resque) | Administrator only |

## Where to Find Detailed Documentation

Each system option area has its own documentation page:

- **[Theaters](theaters.md)** -- Creating and configuring theater companies
- **[Venues](venues.md)** -- Creating performance spaces
- **[Seat Maps](seat-maps.md)** -- Reserved seating layouts
- **[Payment Types](payment-types.md)** -- Payment method configuration
- **[Users](users.md)** -- Staff account management
- **[Service Items](../offers/service-items.md)** -- Fee templates
- **[Special Offers](../offers/special-offers.md)** -- Promotional discounts
- **[Default Ticket Classes](../productions/default-ticket-classes.md)** -- Ticket class templates
- **[Performance Features](../offers/special-features.md)** -- Performance tags
- **[Imports](../imports/imports-overview.md)** -- Bulk data import

## System Configuration (server.yml)

Some system-wide settings are configured at the server level rather than through the admin interface. These include:

| Setting | Description |
|---------|-------------|
| **Order expiration** | How many minutes before an in-progress online order expires (default: 8 minutes) |
| **Public sales cutoff** | Minutes before showtime when public online sales close (default: 120 minutes / 2 hours) |
| **Theater user sales cutoff** | Minutes before showtime when third-party/theater user sales close (default: 30 minutes) |
| **Capacity restriction** | When remaining seats fall below this number, all inventory transfers to box office only (default: 9 seats) |
| **Email addresses** | System email addresses for box office, error notifications, flex pass notifications, membership notifications, and supervisor notifications |
| **Payment gateway** | Stripe configuration for credit card processing |
| **MyEmma integration** | Email marketing platform configuration |

These settings are managed by the system administrator and are not editable through the web interface.
