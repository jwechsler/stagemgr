# Stagemgr: Theater, Production, and Performance Models

## Theater Model
The `Theater` class represents a theater entity within the application. It includes the following key attributes and associations:

- **Attributes**:
  - `name`: The name of the theater, which must be unique and present.
  - `theater_class`: Categorizes the theater as 'Default', 'Co-production', 'Resident Company', 'Visiting Company', or 'Guest Artist'.
  - `status`: Indicates whether the theater is 'Active' or 'Inactive'.
  - `logo`: An attached image representing the theater's logo.

- **Associations**:
  - `has_many :productions`: A theater can have multiple productions.
  - `has_many :special_offers`: Special offers associated with the theater.
  - `has_many :flex_pass_offers`: Flex pass offers associated with the theater.
  - `has_many :orders`: Orders associated with the theater.
  - `has_and_belongs_to_many :users`: Users associated with the theater.

## Production Model
The `Production` class represents a show or production that can have multiple performances. It includes these key attributes and associations:

- **Attributes**:
  - `name`: The name of the production.
  - `season`: The season in which the production is staged.
  - `production_code`: A unique code for the production.
  - `status`: The status of the production, which can be 'Active', 'Private', 'Inactive', 'Presale', or 'Season Seating'.
  - `capacity`: The seating capacity for the production.

- **Associations**:
  - `belongs_to :venue`: The venue where the production is held.
  - `belongs_to :theater`: The theater associated with the production.
  - `has_many :performances`: A production can have multiple performances.
  - `has_many :ticket_classes`: Ticket classes associated with the production.

## Performance Model
The `Performance` class represents a specific performance of a production. Key attributes and associations include:

- **Attributes**:
  - `performance_code`: A unique code for the performance.
  - `performance_date`: The date of the performance.
  - `performance_time`: The time of the performance.
  - `status`: The status of the performance, which can be 'Active', 'Inactive', or 'Private'.

- **Associations**:
  - `belongs_to :production`: The production to which the performance belongs.
  - `has_many :ticket_class_allocations`: Allocations of ticket classes for the performance.
  - `has_many :seats`: Seats available for the performance.
  - `has_many :orders`: Orders for tickets to the performance.

## Ticket Class Model
The `TicketClass` class represents different categories of tickets available for a production. It includes the following key attributes and associations:

- **Attributes**:
  - `class_code`: A unique code for the ticket class within a production.
  - `ticket_type`: The type of ticket, which can be 'Fixed', 'Donation', or 'Timed'.
  - `ticket_price`: The price of the ticket.
  - `ticketing_fee`: Any additional fee associated with the ticket.

- **Associations**:
  - `belongs_to :production`: The production to which the ticket class is associated.
  - `has_many :ticket_class_allocations`: Allocations of this ticket class across performances.
  - `has_many :performances`: Performances that include this ticket class.

## Ticket Class Allocation Model
The `TicketClassAllocation` class manages the allocation of ticket classes to specific performances. Key attributes and associations include:

- **Attributes**:
  - `ticket_limit`: The maximum number of tickets available for this allocation.
  - `shift_days_before_performance`: Days before the performance when a shift in allocation might occur.
  - `shift_when_capacity_over`: The capacity percentage that triggers a shift in allocation.

- **Associations**:
  - `belongs_to :performance`: The performance to which this allocation is associated.
  - `belongs_to :ticket_class`: The ticket class being allocated.

Ticket class allocations also facilitate dynamic pricing through the `shift*` attributes, allowing for price adjustments based on capacity and time before the performance.

## Default Ticket Classes
Default ticket classes are predefined records that are cloned into ticket classes for every production. They serve as templates to ensure consistent ticketing options across different productions.

## Order Model and Subclasses

### Order
- **Inherits From**: `ApplicationRecord`
- **Associations**: 
  - Belongs to `theater`, `performance`, `payment_type`, `address`, and `recipient_address`.
  - Has many `payments`, `exchange_payments`, `tasks`, `seats`, `service_line_items`.
  - Has one `special_offer_line_item`.
- **Validations**: 
  - Ensures presence of `address`.
- **Nested Attributes**: Supports nested attributes for `address`, `tasks`, `payments`, `special_offer_line_item`, and `service_line_items`.
- **Constants**: Defines various order statuses like `HOLD`, `NEW`, `PROCESSED`, etc.
- **Attribute Accessors**: Includes attributes like `special_offer_code`, `door_sale`, `additional_donation`, etc.

### TicketOrder
- **Inherits From**: `Order`
- **Associations**: 
  - Has many `ticket_line_items`.
  - Belongs to `exchange_source` and `split_source`.
- **Validations**: 
  - Ensures presence of `performance`.
  - Validates associated `ticket_line_items`.
  - Includes custom validations for ticket stock and seat assignments.
- **Callbacks**: Utilizes various callbacks for seat assignments and payment validations.

### DonationOrder
- **Inherits From**: `Order`
- **Associations**: 
  - Has many `donation_line_items`.
- **Validations**: 
  - Validates associated `donation_line_items`.
- **Methods**: 
  - `refundable?`, `display_code`, `total`, and `description`.

### FlexPassOrder
- **Inherits From**: `Order`
- **Associations**: 
  - Has one `flex_pass_line_item`.
- **Validations**: 
  - Validates associated `flex_pass_line_item`.
- **Methods**: 
  - `associated_theater_id`, `display_code`, `all_line_items`, and `flex_pass_payments`.

### MembershipOrder
- **Inherits From**: `Order`
- **Includes**: `RecurringOrder`
- **Associations**: 
  - Has one `membership_line_item`.
- **Validations**: 
  - Validates associated `membership_line_item`.
- **Methods**: 
  - `transition_processing_to_processed!`, `display_code`, `recurring_profile`, and `recurring_offer`.

### RecurringOrder (Module)
- **Associations**: 
  - Has many `recurring_payments`.
- **Methods**: 
  - `reactivate`, `suspend!`, `cancel`, `create_recurring_payment`, and `create_missing_recurring_payment`.

## Line Item Models

### TicketLineItem
- **Inherits From**: `LineItem`
- **Associations**: Belongs to `ticket_order` and `ticket_class`.
- **Validations**: Ensures presence of `ticket_count` and numericality of `price_override`.
- **Key Methods**:
  - `ticket_class_allocation_available?`: Checks ticket class allocation availability.
  - `price`: Returns the price, considering overrides and defaults.
  - `refund!`: Handles refund logic for ticket line items.
  - `total`: Calculates the total price based on ticket count.
  - `ticket?`: Confirms the item is a ticket.
  - `to_s`: String representation of the ticket line item.
  - `ticketing_fee`: Calculates the ticketing fee.
- **Callbacks**: Includes `before_validation` and `before_save` hooks.

### ServiceLineItem
- **Inherits From**: `LineItem`
- **Associations**: Belongs to `order`.
- **Validations**: Checks numericality of `amount` and `facility_fee`, and presence of `description`.
- **Key Methods**:
  - `total`: Computes total amount, adjusting for payment type.

### DonationLineItem
- **Inherits From**: `LineItem`
- **Associations**: Belongs to `donation_order`.
- **Validations**: Ensures numericality of `amount`.
- **Key Methods**:
  - `total`: Returns the donation amount.
- **Private Methods**:
  - `set_donation_amount_from_level`: Sets donation amount based on level.

### MembershipLineItem
- **Inherits From**: `LineItem`
- **Associations**: Belongs to `membership_offer`, `membership`, `address`, and `membership_order`.
- **Validations**: Requires presence of `membership_offer`, `membership`, and `address`.
- **Nested Attributes**: Supports nested attributes for `membership`.
- **Private Methods**:
  - `create_membership`: Initializes a new membership.
  - `save_membership`: Saves the membership.
  - `delete_membership`: Deletes the membership.
- **Callbacks**: Utilizes `after_initialize`, `before_save`, and `before_destroy` hooks.

## Address Model
The `Address` class represents a customer's contact information. It includes the following key attributes and associations:

- **Attributes**:
  - `full_name`: The full name of the customer.
  - `email`: The email address of the customer, which is validated for proper format.
  - `line1`, `line2`: Address lines for street address.
  - `city`, `state`, `zipcode`: Components of the customer's address.
  - `phone`: Contact phone number.

- **Associations**:
  - `has_many :orders`: Orders associated with this address.
  - `has_many :address_tags`: Tags associated with this address for categorization.
  - `has_many :memberships`: Memberships linked to this address.
  - `has_many :flex_passes`: Flex passes linked to this address.
  - `has_and_belongs_to_many :productions`: Productions attended by the customer.

## Address Tag Model
The `AddressTag` class is used to tag addresses with additional information. Key attributes and associations include:

- **Attributes**:
  - `tag_label`: The label of the tag used for categorization.
  - `tag_value`: The value associated with the tag.

- **Associations**:
  - `belongs_to :address`: The address to which this tag is applied.
  - `belongs_to :theater`: The theater associated with the tag, if any.

## RecurringProfile
- **Module**: Provides recurring profile functionalities.
- **Associations**: 
  - Belongs to `address`.
- **Validations**: 
  - Ensures presence of `address`.
  - Validates uniqueness of `profile_id`.
- **Callbacks**: 
  - Notifies on suspension after save.
- **Methods**: 
  - Status checks like `active?`, `pending?`, `suspended?`.
  - `create_recurring_profile`, `update_from_profile`, `reactivate`, `cancel`.

## Membership
- **Inherits From**: `ApplicationRecord`
- **Includes**: `RecurringProfile`
- **Associations**: 
  - Has one `membership_line_item`, `membership_order`.
  - Has many `special_offers`, `membership_payments`.
  - Belongs to `membership_offer`, `address`.
- **Validations**: 
  - Ensures presence of `membership_offer`.
- **Callbacks**: 
  - Includes `before_destroy`, `before_validation`, `before_save`.
- **Methods**: 
  - `verify_applicable_for`, `create_code`, `release_reservations_on_cancel`.

## MembershipOffer
- **Inherits From**: `ApplicationRecord`
- **Validations**: 
  - Ensures presence of `name`, `use_ticket_class_code`, `tickets_per_performance`.
  - Validates numericality of `tickets_per_performance`.
- **Methods**: 
  - `has_trial?`, `trial_amount`, `active?`, `take_inactive_off_sale`, `on_sale_to_public?`.

## FlexPass
- **Inherits From**: `ApplicationRecord`
- **Associations**: 
  - Belongs to `address`, `flex_pass_offer`, `flex_pass_line_item`.
  - Has many `flex_pass_payments`.
- **Validations**: 
  - Ensures presence of `expiration_date`, `flex_pass_offer`, `flex_pass_line_item`, `order`, `code`.
- **Callbacks**: 
  - Includes `before_create`, `after_create`, `before_destroy`, `before_validation`.
- **Methods**: 
  - `create_code`, `uses_remaining`, `available?`, `set_expiration_date`, `expired?`, `used_on_orders`, `queue_expiration`.

## FlexPassOffer
- **Inherits From**: `ApplicationRecord`
- **Associations**: 
  - Belongs to `theater`.
  - Has one `production`.
  - Has many `flex_passes`, `flex_pass_line_items`.
- **Validations**: 
  - Ensures presence of `months_till_expiration`, `name`, `price`, `number_of_tickets`, `use_ticket_class_code`.
  - Validates numericality of `price`, `number_of_tickets`.
- **Methods**: 
  - Private method `set_public_sale_by_active`.

These models collectively form the backbone of the Stagemgr application, facilitating the management of theaters, productions, performances, ticket classes, and their allocations.
