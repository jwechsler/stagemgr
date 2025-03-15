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