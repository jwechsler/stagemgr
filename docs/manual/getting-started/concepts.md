# Core Concepts

This page explains the fundamental data model and terminology in Stagemgr. Understanding these concepts will help you navigate the system and use the rest of this manual effectively.

## The Hierarchy: Theater > Production > Performance

Stagemgr organizes events in a three-level hierarchy:

```
Theater
  └── Production
        └── Performance
```

### Theater

A **theater** represents a producing company or organization. A single Stagemgr instance can manage multiple theaters -- for example, a resident company and several visiting companies sharing the same physical spaces.

Each theater has a **theater class** that defines its relationship to the venue:

| Theater Class | Description |
|--------------|-------------|
| **Default** | The primary resident organization that operates the venue |
| **Co-production** | A joint production partnership with the default theater |
| **Resident Company** | A company with an ongoing relationship to the venue |
| **Visiting Company** | A company using the venue for a limited engagement |
| **Guest Artist** | An individual artist or small group using the venue |

Theater class affects permissions -- for example, staff assigned to a Visiting Company theater only see data related to their own productions.

### Production

A **production** is a show -- a play, musical, event, or other programmed content. Productions belong to a theater and have:

- A **production code** (e.g., `ALLY`) -- a short, unique lookup code used by box office staff and as the prefix for performance codes
- A **status** that controls visibility and sales:

| Status | On Website | Public Sales | Box Office Sales |
|--------|-----------|-------------|-----------------|
| **Active** | Yes | Yes | Yes |
| **Private** | No | Yes (with direct link) | Yes |
| **Inactive** | No | No | No |
| **Presale** | Yes | No | Yes |
| **Season Seating** | No | No | Yes (hold only) |

- A **production class** indicating the type of event: Primetime, Special Event, Private Party, Conference, Off/Late night, Class, or External
- A **venue** and optionally a **seat map** for reserved seating
- Run dates: first preview, press opening, opening, and closing
- Ticket classes defining available pricing tiers

### Performance

A **performance** is a single scheduled showing of a production -- a specific date and time when an audience attends. Performances have:

- A **performance code** (e.g., `ALLY0328`) -- always starts with the production code, followed by a date or identifier
- Its own status (Active, Inactive, Private)
- **Ticket class allocations** defining how many tickets of each type are available for that specific performance
- Optional restricted payment types

Performances are where inventory is tracked. When a ticket is sold, it reduces the available count for that specific performance's ticket class allocation.

## Venues and Seat Maps

A **venue** is a physical space where performances take place (e.g., "Mainstage", "Studio Theater"). Venues belong to the Stagemgr instance and can host productions from any theater.

A **seat map** defines the layout of a reserved-seating venue. It contains individual seats with row and location information, and optionally a background image showing the physical layout. When a seat map is assigned to a production, that production uses **reserved seating** -- patrons select specific seats during purchase. Without a seat map, the production uses **general admission**.

A production's **capacity** is automatically determined by the seat map (number of seats) for reserved seating, or set manually for general admission.

## Order Types

Stagemgr handles four types of orders, each serving a different purpose:

### Ticket Order

The primary order type. A patron purchases one or more tickets to a specific performance. Ticket orders include:

- One or more **ticket line items**, each referencing a ticket class and quantity
- Optional **seat assignments** for reserved seating productions
- Optional **service line items** for fees (facility fee, processing fee, etc.)
- Optional **special offer line items** for discounts

### Donation Order

A financial contribution to the theater. Donation orders can be created directly or converted from a ticket order (via "Refund to Donation"). They include a single donation line item with the contribution amount and an optional campaign designation.

### Flex Pass Order

A purchase of a flexible ticket package. A flex pass gives the patron a set number of admissions that can be redeemed across any eligible performances. Flex passes have:

- A **flex pass code** for redemption
- An **expiration date**
- A **remaining admissions** count that decreases with each use

### Membership Order

A purchase of a membership that provides ongoing benefits. Memberships can include a set number of tickets per performance and may have recurring billing.

## Order Lifecycle

Every order moves through a series of states:

```
Hold ──┐
       ├── New ── Processing ── Processed ──┬── Fulfilled
       │                                     ├── Unclaimed
       │                                     ├── Exchanged
       │                                     └── Refunded
       └── Canceled
```

| State | Meaning |
|-------|---------|
| **Hold** | Order is reserved but not yet paid or processed. Box office can convert to a sale later. |
| **New** | Order has been submitted and is awaiting processing. |
| **Processing** | Payment is being processed. |
| **Processed** | Payment is complete. Tickets are confirmed. |
| **Fulfilled** | Tickets have been delivered to the patron (picked up, printed, or emailed). |
| **Unclaimed** | A fulfilled order that has been reverted back, typically for day-of-show will-call management. |
| **Exchanged** | The original order was exchanged for a new order at a different performance or ticket class. |
| **Refunded** | Payment has been returned to the patron. |
| **Canceled** | The order has been canceled with no financial transaction. |

The most common flow for a box office sale is: **New > Processing > Processed > Fulfilled**.

Hold orders are common for season seating and box office holds where payment will be collected later.

## Ticket Classes and Pricing

A **ticket class** defines a type of ticket with a specific price and behavior. Examples:

- "General Admission" at $35
- "Orchestra" at $45
- "Balcony" at $30
- "Student Rush" at $15
- "Complimentary" at $0

Each production has its own set of ticket classes. **Default ticket classes** can be configured at the system level to automatically populate new productions.

Key ticket class properties:

| Property | Description |
|----------|-------------|
| **Class Code** | Short lookup code (e.g., `GA`, `ORCH`) |
| **Price** | Ticket price (cannot be changed after tickets have been sold) |
| **Ticket Type** | Fixed (standard), Donation (pay-what-you-want), or Timed (time-limited availability) |
| **Web Visible** | Whether patrons can see and select this class online |
| **Holds Seats** | Whether purchasing this class reserves a physical seat (relevant for reserved seating) |

### Ticket Class Allocations and Dynamic Pricing

For each performance, a **ticket class allocation** defines how many tickets of that class are available. Allocations can also define **dynamic pricing shifts** -- rules that automatically change the ticket class offered based on:

- **Capacity threshold** -- When a certain percentage of seats are sold, shift to a different (usually higher-priced) ticket class
- **Days before show** -- When the show date approaches, shift pricing

This allows prices to increase automatically as demand grows or the show date nears.

## Payment Types

Stagemgr supports multiple payment methods:

| Payment Type | Description |
|-------------|-------------|
| **Credit Card** | Processed through Stripe |
| **Cash** | Cash payment at the box office |
| **Check** | Check payment |
| **External** | Custom payment types defined by the theater (e.g., gift certificate, sponsor comp) |
| **Flex Pass** | Redeemed from a patron's flex pass balance |
| **Membership** | Included with a patron's membership benefits |
| **Comp** | Complimentary (no payment required) |

Payment types can be configured with restrictions -- for example, certain types may only be available at the box office, or certain types may suppress confirmation emails.

## Patrons (Addresses)

In Stagemgr, a patron's contact information is stored in an **address** record. This is the system's customer database. Each address record contains:

- Name, email, phone, and mailing address
- Order history across all theaters and productions
- Custom **tags** for segmentation and tracking (e.g., donor level, VIP status, external system IDs)
- Email marketing opt-in status

Address records are shared across all theaters in the system. When a patron buys tickets from different theaters, their orders are linked through a single address record.

## Service Items and Fees

**Service items** are fees automatically added to orders. Common examples:

- Facility fee (per ticket)
- Processing fee (per order)
- Exchange fee

Service items follow an **inheritance chain**: system-wide defaults can be overridden at the theater level, which can be overridden at the production level. This allows different fee structures for different theaters or productions while maintaining sensible defaults.

## Special Offers

A **special offer** is a promotional discount applied with a code during checkout. There are four types:

| Offer Type | Effect |
|-----------|--------|
| **Percent Off** | Reduces the ticket price by a percentage |
| **Amount Off** | Reduces the ticket price by a fixed dollar amount |
| **Ticket Class Change** | Swaps the ticket to a different (usually cheaper) ticket class |
| **Buy X Get Y** | Frees the cheapest tickets for every full group bought (e.g. buy 2, get 1 free) |

Special offers can be scoped to specific theaters, productions, or performances, and can have date ranges, day-of-week restrictions, and usage limits.
