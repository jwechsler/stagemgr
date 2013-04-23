Feature: Web ordering
  As an web site user
  I want to be able to buy tickets, using a variety of payment methods

  Background:
    Given a sample theater exists
    And a special offer exists with code "1DollarOff" for $1 off
  Scenario: Create an order
    Given I go to new web order for production "Production One" and performance "PERF"
    And I enter my contact information
    And I select "2" from "ticket_order_ticket_line_items_attributes_0_ticket_count"
    And I enter a valid credit card as payment
    And I press "Review Order"
    And I press "Order Tickets"
    Then I should see "$10.00"
    Then I should see "Your ticket reservation has been made"

  Scenario: Create an order with a special offer
    Given I go to new web order for production "Production One" and performance "PERF"
    And I enter my contact information
    And I select "1" from "ticket_order_ticket_line_items_attributes_1_ticket_count"
    And I enter a valid credit card as payment
    And I fill in "Discount Code (optional)" with "1DollarOff"
    And I press "Review Order"
    And I should see "9.00"
    And I press "Order Tickets"
    Then I should see "Your ticket reservation has been made"
    And I should see "9.00"

  # Scenario: Have the credit card declined and then try again successfully
  #   Given I go to new web order for production "Production One" and performance "PERF"
  #   And I enter my contact information
  #   And I select "0" from "ticket_order_ticket_line_items_attributes_0_ticket_count"
  #   And I select "1" from "ticket_order_ticket_line_items_attributes_1_ticket_count"
  #   And I enter a valid credit card as payment
  #   And I change "Credit card number" to "2"
  #   And I press "Review Order"
  #   And I press "Order Tickets"
  #   And I should see "Please enter a valid credit card number"
  #   And I select "1" from "ticket_order_ticket_line_items_attributes_1_ticket_count"
  #   And I select "0" from "ticket_order_ticket_line_items_attributes_0_ticket_count"
  #   And I enter a valid credit card as payment
  #   And I press "Review Order"
  #   And I press "Order Tickets"
  #   Then I should see "Your ticket reservation has been made"
  #   And I should see "$10.00"

  Scenario: Sign up for the mailing list
    Given I go to new web order for production "Production One" and performance "PERF"
    And I enter my contact information
    And I select "1" from "ticket_order_ticket_line_items_attributes_1_ticket_count"
    And I enter a valid credit card as payment
    And I check "ticket_order_add_to_email_list"
    And I press "Review Order"
    And I press "Order Tickets"
    Then the order should have an email task


