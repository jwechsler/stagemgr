# Technical Changes: FlexPass Order Cancellation and Refund Logic

## Overview
Enhanced the FlexPass order cancellation logic to properly handle refunds and deletions based on redemption status. When a FlexPass has no redemptions, the order is refunded and the FlexPass is deleted. When a FlexPass has redemptions, it is only deactivated without refund. Additionally, fixed view errors that occurred when displaying orders with deleted FlexPasses.

## Changes Made

### 1. Updated FlexPassOrder Cancellation Logic
Modified the `cancel!` method in the FlexPassOrder model to implement new business rules:

```ruby
def cancel!
  if flex_pass.upcoming_ticket_orders.count > 0 then
    errors.add(:error, "Cannot cancel a flex_pass with upcoming ticket orders")
    false
  else
    Order.transaction do
      if !flex_pass.has_placed_orders?
        # No redemptions - refund and delete the flex pass
        refund!
        flex_pass.destroy!
        # Note: refund! already sets status to REFUNDED
        errors.add(:info, "Flex Pass #{flex_pass.code} has been refunded and deleted")
      else
        # Has redemptions - just deactivate the flex pass, leave order status unchanged
        flex_pass.active=false 
        flex_pass.save!
        errors.add(:info, "Flex Pass #{flex_pass.code} inactive")
      end
      true
    end
  end
end
```

#### Key Business Rules:
- **No redemptions**: Order is refunded (status → REFUNDED), FlexPass is deleted
- **Has redemptions**: FlexPass is deactivated, order status remains unchanged
- **Has upcoming orders**: Cancellation is prevented entirely

### 2. Fixed View Errors for Deleted FlexPasses
Updated views to gracefully handle nil FlexPass references after deletion:

#### Modified Files:
- `app/views/flex_pass_orders/show.html.haml`
- `app/views/admin/flex_pass_orders/show.html.haml`
- `app/views/admin/flex_pass_line_items/_flex_pass_line_item.html.haml`

#### Key Changes:
- Added presence checks before rendering FlexPass details
- Used safe navigation operator (`&.`) in decorator calls
- Display "No associated flex pass" message when FlexPass is nil

### 3. Created FlexPassOrder Factory
Added a proper factory for FlexPassOrder to support testing:

```ruby
factory :flex_pass_order do
  status                  { Order::ORDER_STATUSES.first }
  association             :address, :factory => :address
  association             :payment_type, :factory => :cash_payment_type
  
  transient do
    flex_pass_offer { nil }
    skip_line_item { false }
  end
  
  after(:create) do |flex_pass_order, evaluator|
    # Creates associated flex_pass_line_item and flex_pass
  end
  
  trait :with_payment do
    # Adds payment and sets status to PROCESSED
  end
end
```

### 4. Added Comprehensive Test Coverage
Created full RSpec test suite for the cancellation behavior:

#### Test Scenarios:
- FlexPass with upcoming ticket orders (cancellation prevented)
- FlexPass with no redemptions (refunded and deleted)
- FlexPass with past redemptions (deactivated only)
- Transaction rollback on errors

## Technical Details

### Design Decisions
- Used database transaction to ensure atomicity of refund and deletion
- Leveraged existing `refund!` method which automatically sets order status to REFUNDED
- Maintained backward compatibility by not changing order status for partially-used FlexPasses

### Factory Structure
- Resolved circular dependency between `flex_pass` and `flex_pass_line_item` factories
- Used transient attributes for flexible factory configuration
- Removed duplicate factory definition in `test/factories.rb`

### View Safety
- Implemented defensive programming with presence checks
- Used safe navigation operator to prevent NoMethodError on nil objects
- Provided user-friendly messaging when FlexPass is missing

## Pull Request
The changes were committed to the `refund_fp` branch. The implementation includes the updated cancellation logic, view fixes, factory improvements, and comprehensive test coverage.

# Technical Changes: External Events Email Notification

## Overview
Added logic to suppress location-specific content (theater address, dining options, etc.) in email templates for productions with type EXTERNAL or CONFERENCE. These types of events often don't occur at Theater Wit's physical location, so making location assumptions in the emails was problematic.

## Changes Made

### 1. Added Helper Method to Production Model
Added a new method to the Production model to identify external/conference events:

```ruby
# Indicates whether this production should be treated as a special event
# for email notification purposes - avoiding location-specific content
def treat_as_special_event?
  self.production_class.eql?(Production::EXTERNAL) || self.production_class.eql?(Production::CONFERENCE)
end
```

### 2. Updated Email Templates
Modified several email view templates to use the new logic:

#### Modified Files:
- `app/views/order_mailer/_performance_info.html.haml`
- `app/views/order_mailer/_performance_reminder.html.haml`
- `app/views/order_mailer/_performance_confirmation.html.haml`
- `app/views/order_mailer/_seating_information.html.haml`
- `app/views/order_mailer/_generic_reminder.html.haml` (Fixed a bug with `production_name` → `name`)

#### Key Changes:
- Conditional templating using the new `treat_as_special_event?` method
- Suppressed theater location, dining recommendations, and transportation details 
- Customized language for external events (e.g., "door" vs "box office")
- Maintained essential information (show time, date, confirmation details)

### 3. Added Comprehensive Tests
Created full test suite for email content differences:

#### Test Coverage:
- Verified regular productions include location-specific content
- Confirmed EXTERNAL and CONFERENCE productions exclude location-specific content
- Ensured all production types still include essential information (name, date, time)
- Used robust test patterns to handle HTML-encoded content

## Technical Details

### Design Pattern Used
- DRY principle: Created a single helper method to determine if a production is a special event type
- Template pattern: Conditionally rendered HTML fragments based on the production type

### Testing Approach
- Created specific test cases for both email types (performance reminder and ticket confirmation)
- Used both positive tests (content exists for regular productions) and negative tests (content excluded for external/conference)
- Added robust pattern matching for HTML content to avoid fragile tests

### Notes
- Template modifications were minimal with the use of the helper method
- Maintained existing functionality for regular production types
- Fixed a bug in `_generic_reminder.html.haml` where an undefined method `production_name` was being called (changed to `name`)
- RSpec tests verify all combinations of production types and email templates

## Pull Request
The changes were committed to the `external_notify` branch. The commit includes both the implementation changes and corresponding test coverage.