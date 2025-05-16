# Stagemgr: Theater, Production, and Performance Models

## Metrics and Reporting Framework

The application includes a robust metrics framework for tracking, calculating, and exporting various performance and sales data:

### Metric (Abstract Base Class)
- **Purpose**: Serves as the parent class for all metric models
- **Type**: Abstract class (cannot be instantiated directly)
- **Key Features**:
  - Includes `MetricsExporter` module for standardized export functionality
  - Defines abstract methods that subclasses must implement:
    - `export_columns`: Specifies columns for export
    - `export_records`: Defines which records should be included in exports

### MetricsExporter (Concern)
- **Purpose**: Provides standardized methods for data export
- **Key Methods**:
  - `export_to_file`: Exports selected records to formatted text files
  - `format_records`: Formats data into tabular output
  - `format_header`: Converts column names to human-readable headers

### RateOfSale Model
- **Inherits From**: `Metric`
- **Purpose**: Tracks daily ticket sales metrics per production
- **Key Attributes**:
  - `day_of_sale`: Date for which sales are tracked
  - `production_id`: Associated production
  - `total_single_tickets`: Number of regular tickets sold
  - `total_complimentary_tickets`: Number of comp tickets issued
  - `gross_sales`: Total revenue (decimal 8,2)
  - `processing_fees`: Total fees collected (decimal 8,2)
- **Associations**:
  - `belongs_to :production`
  - `has_one :theater, through: :production`
- **Related Job**: `RateOfSalesJob` calculates metrics for the previous day

### HouseCount Model
- **Inherits From**: `Metric`
- **Purpose**: Tracks real-time seat inventory for each performance
- **Key Attributes**:
  - `performance_id`: Associated performance
  - `total_seats`: Total number of seats for the venue
  - `sold_seats`: Number of seats sold
  - `available_seats`: Number of seats still available
- **Key Methods**:
  - `calculate`: Computes the current seat counts
  - `calculate!`: Updates and saves the seat counts
- **Related Job**: `CalculateHouseCountsJob` updates counts when orders change

### JobMetadata Model
- **Purpose**: Tracks the execution history of background jobs
- **Key Attributes**:
  - `job_name`: The name of the background job
  - `last_run_at`: Timestamp of the last successful run
- **Key Methods**:
  - `record_last_run`: Updates the timestamp for a job
  - `last_run`: Retrieves the last run time for a job

## Job Framework and Concerns

The application includes a job framework for scheduling and executing background tasks:

### LoggedJob (Concern)
- **Purpose**: Tracks job execution in the JobMetadata table
- **Key Features**:
  - Automatically records job completion time
  - Enables tracking of last run time for incremental processing

### NotifyOnCompletion (Concern)
- **Purpose**: Notifies users when long-running jobs complete
- **Key Methods**:
  - `notify_user_on_completion`: Sends an email notification with a link to download generated files

### Background Jobs
- **CalculateHouseCountsJob**:
  - **Purpose**: Updates seat counts for performances
  - **Frequency**: Real-time (triggered by order changes)
  - **Features**: Uses Resque lock to prevent concurrent runs
  
- **ExportHouseCountsJob**:
  - **Purpose**: Exports house counts to a formatted text file
  - **Frequency**: Daily
  - **Output**: Tab-delimited file with seat counts for upcoming performances
  
- **RateOfSalesJob**:
  - **Purpose**: Calculates daily sales metrics
  - **Frequency**: Daily (processes previous day's data)
  - **Features**: 
    - Updates metrics for each production with sales
    - Exports data for reporting and analysis
    
- **TrgProductionAttendeeExportJob**:
  - **Purpose**: Generates attendee reports for specific productions
  - **Frequency**: On-demand (user triggered)
  - **Features**: Notifies the user when the report is ready for download

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

## Order Tasks and Notifications

### NotificationTask
- **Inherits From**: `OrderTask`
- **Purpose**: Handles email notifications for various order-related events
- **Key Attributes**:
  - `notifications`: Comma-separated list of recipient email addresses
  - `method_symbol`: Determines which type of notification to send
  - `result`: Stores error messages and backtraces from failed attempts
  - `attempts`: Tracks number of delivery attempts (limits to 8)

- **Key Methods**:
  - `execute!`: Processes the notification task
    - Validates presence of notifications and attempt count
    - Iterates through recipients and sends emails
    - Handles errors and stores results
  - `cancel_with_order?`: Returns false (notifications persist even if order is cancelled)

### NotificationMailer
- **Inherits From**: `ActionMailer::Base`
- **Layout**: Uses custom "notification_mailer" layout
- **Notification Types**:
  - `wheelchair_conversion_alert`: For wheelchair accommodation requests
  - `suspension_alert`: For suspended payment notifications
  - `file_generated`: For file download notifications

- **Features**:
  - Uses Foundation for Email framework for styling
  - Supports both HTML and text email formats
  - Includes email categorization via tags
  - Integrates with ApplicationHelper for shared functionality

### OrderMailer
- **Inherits From**: `ActionMailer::Base`
- **Purpose**: Handles all order-related email communications including confirmations, reminders, and follow-ups
- **Layout**: 
  - Default: "order_mailer"
  - Alternative: "order_mailer_no_sidebar" for specific email types
- **Features**:
  - Markdown Support via Redcarpet
  - ERB templating for dynamic content
  - Foundation for Email framework styling
  - Email categorization via tags

#### Email Types and Methods

1. **Ticket Related**:
   - `ticket_confirmation(order, address=nil, action_by=nil)`:
     - Sends order confirmation for ticket purchases
     - Includes custom confirmation messages from production
     - Tagged as "Ticket Confirmation"
   
   - `performance_reminder(order, address=nil, action_by=nil, testing=false)`:
     - Sends reminders for upcoming shows
     - Only sends if performance is >1 day away
     - Can be suppressed via performance settings
     - Tagged as "Ticket Reminder"

2. **Membership Related**:
   - `membership_confirmation(order, address=nil, action_by=nil)`:
     - Confirms membership purchases
     - Tagged as "Membership Confirmation"
   
   - `member_followup(order, address=nil, action_by=nil)`:
     - Post-show follow-up for members
     - Includes customizable follow-up messages
     - Sent from artistic director

3. **Donation Related**:
   - `donation_thank_you(order, address=nil, action_by=nil)`:
     - Thanks donors for contributions
     - Uses no-sidebar layout
     - Sent from artistic director
     - Tagged as "Donation Thank You"

4. **FlexPass Related**:
   - `flexpass_confirmation(order, address=nil, action_by=nil)`:
     - Confirms FlexPass purchases
     - Uses no-sidebar layout
     - Tagged as "Flex Pass Confirmation"
   
   - `flex_pass_followup(order, address=nil, action_by=nil)`:
     - Post-show follow-up for FlexPass holders

5. **Administrative**:
   - `refunded_fulfilled_item_alert(order, email, action_by)`:
     - Alerts staff about refunds on fulfilled orders
     - Tagged as "Alert"
   
   - `test_message(address)`:
     - For testing email functionality
     - Tagged as "Test Message"

#### View Structure

1. **Core Templates**:
   - `ticket_confirmation.html.haml`
   - `performance_reminder.html.haml`
   - `donation_thank_you.html.erb`
   - `flexpass_confirmation.html.haml`
   - `membership_confirmation.html.erb`

2. **Shared Partials**:
   - Performance Information:
     - `_performance_info.html.haml`
     - `_performance_confirmation.html.haml`
     - `_performance_reminder.html.haml`
   
   - Customer Information:
     - `_contact_information.html.haml`
     - `_charge_information.html.haml`
   
   - Venue Information:
     - `_seating_information.html.haml`
     - `_seating_policy.html.haml`
     - `_transportation_instructions.html.haml`
   
   - Additional Information:
     - `_dining_recommendations.html.haml`
     - `_also_playing.html.haml`
     - `_special_features.html.haml`

3. **Styling**:
   - Uses Foundation for Email framework
   - Styles defined in `_foundation_email_css.html.haml`

#### Key Features

1. **Content Customization**:
   - Markdown rendering for formatted content
   - ERB templating for dynamic messages
   - Production-specific confirmation and follow-up messages

2. **Control and Flexibility**:
   - Performance-level notification suppression
   - Timing checks for reminders
   - Multiple layout options
   - Different sender addresses for various email types

3. **Modularity**:
   - Extensive use of partials for reusable components
   - Consistent styling through Foundation framework
   - Separate layouts for different email types

### Email Templates
- Written in HAML format
- Located in app/views/notification_mailer/
- Includes shared layouts and partials for consistent styling
- Supports preview functionality via OrderMailerPreview

The notification system provides a robust framework for:
- Separating concerns between task management and email delivery
- Supporting multiple notification types and recipients
- Implementing retry logic for failed notifications
- Maintaining consistent email presentation
- Error handling and logging

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

## FlexPass System

The FlexPass system provides flexible ticketing options for patrons, allowing them to purchase a bundle of tickets upfront and use them for various performances over time.

### FlexPass
- **Inherits From**: `ApplicationRecord`
- **Purpose**: Represents a specific flex pass purchased by a customer
- **Associations**: 
  - Belongs to `address`: The customer who owns the flex pass
  - Belongs to `flex_pass_offer`: The offer type defining the flex pass rules
  - Belongs to `flex_pass_line_item`: The line item from the original purchase order
  - Has many `flex_pass_payments`: Records of tickets purchased using this flex pass
- **Key Attributes**:
  - `code`: Unique identifier code for the flex pass (auto-generated)
  - `expiration_date`: Date when the flex pass expires (calculated from creation date)
  - `active`: Boolean indicating if the flex pass is active
- **Validations**: 
  - Ensures presence of `expiration_date`, `flex_pass_offer`, `flex_pass_line_item`, `order`, `code`
- **Callbacks**: 
  - `before_create`: Sets default values and generates a unique code
  - `after_create`: Sets the expiration date
  - `before_destroy`: Validates the flex pass can be safely removed
  - `before_validation`: Ensures required fields are present
- **Key Methods**: 
  - `create_code`: Generates a unique code for the flex pass
  - `uses_remaining`: Calculates how many tickets are still available to use
  - `available?`: Checks if the flex pass is valid for use (not expired and has uses left)
  - `set_expiration_date`: Calculates expiration date based on flex pass offer rules
  - `expired?`: Checks if the flex pass has expired
  - `used_on_orders`: Retrieves orders where this flex pass was used
  - `queue_expiration`: Sets up expiration jobs for later processing

### FlexPassOffer
- **Inherits From**: `ApplicationRecord`
- **Purpose**: Defines the rules and pricing for a type of flex pass
- **Associations**: 
  - Belongs to `theater`: The theater that offers this flex pass
  - Has one `production`: A production specifically associated with this offer (optional)
  - Has many `flex_passes`: Individual flex passes created from this offer
  - Has many `flex_pass_line_items`: Order line items for this offer type
- **Key Attributes**:
  - `name`: Display name of the flex pass offer
  - `price`: Base price of the flex pass
  - `number_of_tickets`: Number of tickets included in the flex pass
  - `facility_fee`: Fee paid to the facility for each flex pass sold
  - `spiff`: Additional incentive amount (commission)
  - `flat_payout`: Fixed payout amount
  - `use_ticket_class_code`: Ticket class code to use when redeeming flex pass tickets
  - `months_till_expiration`: Number of months before expiration
  - `active`: Whether the offer is active and available for purchase
  - `on_sale_to_public`: Whether the offer is publicly available
  - `redeem_immediately`: Whether tickets are redeemed immediately upon purchase
- **Validations**: 
  - Ensures presence of `months_till_expiration`, `name`, `price`, `number_of_tickets`, `use_ticket_class_code`
  - Validates numericality of `price`, `number_of_tickets`
- **Key Methods**: 
  - `set_public_sale_by_active`: Updates public sale status based on active status

### FlexPassPayment
- **Purpose**: Records when a flex pass is used to "pay" for a ticket purchase
- **Inherits From**: Payment model
- **Key Attributes**:
  - `flex_pass_id`: The flex pass being used to pay
  - `order_id`: The ticket order being paid for
  - `amount`: The monetary value of the payment (calculated from ticket price)
  - `number_of_tickets`: Number of tickets this payment covers
  - `processed_on`: When the payment was processed
- **Relationships**:
  - Belongs to `flex_pass`: The flex pass used for payment
  - Belongs to `order`: The order being paid for with the flex pass

### FlexPassOrder
- **Inherits From**: `Order`
- **Purpose**: Represents an order to purchase a flex pass
- **Associations**: 
  - Has one `flex_pass_line_item`: The line item for the flex pass purchase
- **Validations**: 
  - Validates associated `flex_pass_line_item`
- **Key Methods**: 
  - `associated_theater_id`: Returns the theater ID
  - `display_code`: Shows a human-readable order code
  - `all_line_items`: Returns all line items (typically just one for the flex pass)
  - `flex_pass_payments`: Gets payments made with this flex pass

### FlexPassLineItem
- **Inherits From**: `LineItem`
- **Purpose**: Represents a flex pass in an order
- **Associations**:
  - Belongs to `flex_pass_offer`: The offer defining this flex pass
  - Belongs to `flex_pass_order`: The order purchasing this flex pass
  - Has one `flex_pass`: The flex pass created from this line item
- **Key Methods**:
  - `total`: Calculates the total price of the flex pass
  - `description`: Provides a human-readable description

### FlexPassUsageReport
- **Inherits From**: `Report`
- **Purpose**: Generates reports on flex pass usage and financials
- **Key Functionality**:
  - Tracks new flex passes purchased during a period
  - Calculates ticket values redeemed with flex passes
  - Monitors expired flex passes and recovered amounts
  - Calculates financial metrics including:
    - New deposits from flex pass sales
    - Tickets paid out using flex passes
    - Facility fees collected
    - Spiffs and flat payouts
    - Recovered amounts from expired unused passes
- **Implementation Details**:
  - Groups data by month for trend analysis
  - Allows filtering by specific flex pass offer types
  - Supports both on-screen viewing and CSV export
  - Used for financial reconciliation and marketing analysis

### FlexPassUsageExport
- **Inherits From**: `ReportExport`
- **Purpose**: Background job to export flex pass usage data
- **Queue**: Processed in the `report` queue
- **Key Functionality**:
  - Generates a CSV report of flex pass usage
  - Notifies the requesting user upon completion
  - Uses the NotifyOnCompletion concern for email notifications

The FlexPass system forms a comprehensive solution for managing bundled ticket purchases, providing flexibility for patrons while maintaining accurate financial tracking for theaters. The reporting capabilities enable analysis of flex pass performance, revenue recognition, and usage patterns over time.

These models collectively form the backbone of the Stagemgr application, facilitating the management of theaters, productions, performances, ticket classes, and their allocations.
