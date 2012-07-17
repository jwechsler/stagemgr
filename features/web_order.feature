Feature: Web ordering
  As an web site user
  I want to be able to buy tickets, using a variety of payment methods

  Background:
    Given a theater "Test Theater" exists
    And the following Productions exist on the Theater "Test Theater":
      | name           | production_code |
      | Production One | TEST            |
    And the following TicketClasses exist on the Production "Production One":
      | class_code | class_name       | ticket_price | web_visible | software_managed |
      | CHEAP      | Cheap Ticket     | 5.00         | true        | false            |
      | RICH       | Expensive Ticket | 10.00        | true        | false            |
      | SECRET     | Secret Ticket    | 20.00        | false       | false            |
      | MEMBER     | Membership Rate  | 1.00         | false       | true             |
    And the following performances exist on the Production "Production One":
      | performance_code |
      | PERF             |
    And all the ticket class are available for Performance "PERF"
    And the following amount_off_special_offers exist:
      | amount | code       |
      | 1      | 1DollarOff |

  Scenario: Create an order
    Given I go to new web order for production "Production One" and performance "PERF"
    And I enter my contact information
    And I select "2" from "ticket_order_ticket_line_items_attributes_0_ticket_count"
    And I enter a valid credit card as payment
    And I press "Review Order"
    And I press "Order Tickets"
    Then I should see "$10.00"
     And I should see "Your ticket reservation has been made"

  Scenario: Create an order with a special offer
    Given I go to new web order for production "Production One" and performance "PERF"
    And I enter my contact information
    And I select "1" from "ticket_order_ticket_line_items_attributes_1_ticket_count"
    And I enter a valid credit card as payment
    And I fill in "Discount Code (optional)" with "1DollarOff"
    And I press "Review Order"
    And I see "9.00"
    And I press "Order Tickets"
    Then I should see "Your ticket reservation has been made"
     And I should see "$9.00"

  Scenario: Have the credit card declined and then try again successfully
    Given I go to new web order for production "Production One" and performance "PERF"
    And I enter my contact information
    And I select "0" from "ticket_order_ticket_line_items_attributes_0_ticket_count"
    And I select "1" from "ticket_order_ticket_line_items_attributes_1_ticket_count"
    And I enter a valid credit card as payment
    And I change "Credit card number" to "4222222222222"
    And I press "Review Order"
    And I press "Order Tickets"
    And I should see "Please enter a valid credit card number"
    And I select "1" from "ticket_order_ticket_line_items_attributes_1_ticket_count"
    And I select "0" from "ticket_order_ticket_line_items_attributes_0_ticket_count"
    And I enter a valid credit card as payment
    And I press "Review Order"
    And I press "Order Tickets"
   Then I should see "Your ticket reservation has been made"
    And I should see "$10.00"

