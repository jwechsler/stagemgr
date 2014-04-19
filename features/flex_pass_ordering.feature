Feature: Flex Pass Ordering
  As an web site user
  I want to be able to pay for my ticket order with a flex pass

  Background:
    Given a sample theater exists
    And the system accepts flex passes
    And a flex pass exists for 2 tickets with code "TESTFLEX"

  Scenario: Purchase tickets with a flex pass code
    Given I go to new web order for production "Production One" and performance "PERF"
      And I enter my contact information
      And I select "2" from "ticket_order_ticket_line_items_attributes_0_ticket_count"
      And I enter flex pass code "TESTFLEX" as payment
      And I press "Review Order"
      And I press "Order Tickets"
      Then I should see "0 tickets remaining"
      Then I should see "Your ticket reservation has been made"

  Scenario: Limit tickets to flex pass maximum
    Given I go to new web order for production "Production One" and performance "PERF"
      And I enter my contact information
      And I select "3" from "ticket_order_ticket_line_items_attributes_0_ticket_count"
      And I enter flex pass code "TESTFLEX" as payment
      And I press "Review Order"
      And I press "Order Tickets"
     Then I should see "Number of tickets cannot be more than the number of tickets left on flex pass."