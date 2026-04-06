# Glossary

!!! info "Reference"
    Alphabetical glossary of domain terms used throughout Stagemgr and this manual.

## A

### Address
A customer record in Stagemgr containing name, postal address, email, phone, and associated tags. Also referred to as a "customer" or "patron record." Every order is linked to an address.

### Allocation
See [Ticket Class Allocation](#ticket-class-allocation).

### Auto-Attach
A setting on special offers that automatically applies the offer to qualifying orders without requiring a promo code. When enabled, the offer is applied to every eligible order at checkout.

## C

### Capacity
The maximum number of tickets that can be sold for each performance of a production. For reserved seating productions, capacity is derived automatically from the seat map's seat count. For general admission productions, capacity is set manually on the production edit form. See [Capacity Management](../advanced/capacity-management.md).

### Comp
A complimentary ticket issued at no charge. Comp tickets are created using a comp payment type and reduce available inventory but generate no revenue. Comp ticket classes are typically configured separately from paid classes.

## D

### Dynamic Pricing
A system where ticket prices shift automatically based on demand (capacity percentage sold) or timing (days before performance). Configured through shiftable ticket class allocations. See [Dynamic Pricing](../productions/dynamic-pricing.md).

## E

### Exchange
The process of moving a patron from one performance to another, or from one ticket class to another, within the same production. Exchanges can involve a price differential that is charged or refunded. Available on processed or fulfilled ticket orders.

## F

### Flex Pass
A prepaid multi-admission pass that entitles the holder to a set number of ticket redemptions across any eligible performances. Flex passes have expiration dates and are tracked by remaining admissions. See [Flex Pass Offers](../offers/flex-pass-offers.md).

### Fulfill
The act of marking an order as delivered to the patron. For ticket orders, this typically happens when the patron picks up tickets at will-call or checks in at the door. Fulfillment moves the order from PROCESSED to FULFILLED status.

## G

### General Admission
A production configuration where tickets are not assigned to specific seats. Patrons receive tickets for a performance but choose their own seating upon arrival. General admission productions use manual capacity settings.

## H

### Hold
An order status indicating that the order has been created but not yet processed. Held orders reserve inventory (seats or ticket counts) but no payment has been collected. Held orders can be processed, canceled, or released.

### House Count
A real-time inventory snapshot for a performance showing total seats, tickets sold, tickets held, seats remaining, and booking percentage. House counts are recalculated periodically by background jobs and displayed on the dashboard and in house management reports.

### HUD
Heads-Up Display. The on-screen overlay during house management that shows real-time performance statistics including sold count, held count, checked-in count, and remaining seats.

## L

### Line Item
An individual entry within an order representing a specific purchased item. Types include ticket line items, donation line items, flex pass line items, membership line items, and service fee line items.

## M

### Membership
A recurring patron benefit that provides perks such as discounted tickets, priority seating, or other privileges for a defined period. Membership orders are separate from ticket orders and can be renewed.

### MyEmma
A third-party email marketing platform integrated with Stagemgr. Productions can be linked to MyEmma email groups so that ticket buyers are automatically added to marketing lists. Used for audience development and patron communication.

## O

### Order
A transaction record in Stagemgr. Orders have types (TicketOrder, DonationOrder, FlexPassOrder, MembershipOrder), states (NEW, PROCESSING, PROCESSED, FULFILLED, UNCLAIMED, CANCELED), and are linked to a customer address, a theater, and one or more line items.

## P

### Payment Type
A method of payment configured in the system. Examples include credit card, cash, check, comp, flex pass, and membership. Payment types determine how revenue is recorded and whether financial transactions are processed.

### Performance
A single scheduled showing of a production at a specific date and time. Each performance has its own ticket class allocations, seat assignments, and house count. Performances belong to a production.

### Performance Code
A unique identifier for a performance, typically formatted as a combination of the production code and date (e.g., `ALLY-0315`). Used in imports and reports to reference specific performances.

### Production
A show, event, or engagement in Stagemgr. A production belongs to a theater and a venue, contains one or more performances, and defines ticket classes, pricing, descriptions, and email communications for the run.

### Production Code
A short unique identifier for a production (e.g., `ALLY`, `HAMLET`). Used in imports, reports, and as a reference in performance codes.

## R

### Reserved Seating
A production configuration where each ticket is assigned to a specific seat. Reserved seating requires a seat map to be assigned to the production. Capacity is automatically derived from the seat map's seat count.

## S

### Seat Assignment
The link between a ticket line item and a specific seat in a seat map. Seat assignments are created when a reserved seating ticket is purchased and released when the order is canceled or refunded.

### Seat Map
A configuration of named seats organized within a venue. Seat maps define the physical layout (sections, rows, seat numbers) and determine capacity for reserved seating productions. A venue can have multiple seat maps for different configurations.

### Service Item
An add-on charge or fee attached to an order, such as a facility fee, processing fee, or other surcharge. Service items are configured through service item templates and applied automatically or manually to orders.

### Shift
In dynamic pricing, a shift is the automatic redirection of a ticket purchase from one ticket class to another when a trigger condition (capacity threshold or time threshold) is met. See [Dynamic Pricing](../productions/dynamic-pricing.md).

### Special Feature
A tag or attribute that can be assigned to a performance to indicate special characteristics, such as "ASL Interpreted," "Audio Described," "Post-Show Q&A," or "Preview." Special features appear on the public purchase page.

### Special Offer
A promotional discount or code-based offer that reduces the price of tickets. Special offers can require a promo code or auto-attach to qualifying orders. They can be limited by date range, usage count, or specific ticket classes.

## T

### Theater
The top-level organizational unit in Stagemgr. A theater represents a producing company or organization. Each theater has its own productions, payment types, users, and configuration. A single Stagemgr instance can manage multiple theaters.

### Ticket Class
A pricing tier for tickets (e.g., "General Admission," "Student," "Senior," "VIP"). Each ticket class has a code, name, price, and various configuration options including web visibility, purchase limits, and dynamic pricing settings.

### Ticket Class Allocation
A per-performance record that links a ticket class to a specific performance and controls how many tickets of that class can be sold. Allocations also contain dynamic pricing (shiftable) settings.

### Timed Ticket
A ticket class that only becomes available for purchase within a specified number of minutes before the performance start time. Used for day-of-show pricing or walk-up sales. Configured via the `minutes_before_show` field on the allocation.

## U

### Unclaim
The act of marking a fulfilled order as unclaimed, indicating the patron did not pick up or use their tickets. This status is used for tracking no-shows in house management.

## V

### Venue
A physical location where performances take place. Venues belong to a theater and can have multiple seat maps for different room configurations. The venue determines which seat maps are available when creating a production.
