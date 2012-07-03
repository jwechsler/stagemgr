@wip
Feature: Box office ordering
  As an administrator
  I want to create / edit and delete performances records

  Background:
  Given the following productions exist:
    | name             | production_code |
    | Production One   | ABC12           |
    And the following ticket_classes exist on the Production "Production One":
    | class_code | class_name | ticket_price |
    | A          | A Ticket   | 10.00        |
    | B          | B Ticket   | 15.00        |
    | C          | C Ticket   | 20.00        |
    And the following performances exist on the Production "Production One":
      | performance_code |
      | PERF             |
    And I am an Administrator
    And I am logged in
    And I go to New Box Office Order

  Scenario: Create an order
  Given I fill in "Production code" with "ABC12"
    And I fill in "Performance code" with "PERF"
    And I fill in "order_ticket_line_items_attributes_0_ticket_class_code" with "A"
    And I fill in "order_ticket_line_items_attributes_0_ticket_count" with "2"
    And I fill in "First name" with "PERF"
    And I fill in "Last name" with "PERF"
    And I fill in "Address Line1" with "PERF"
    And I fill in "Address Line2" with "PERF"
    And I fill in "City" with "PERF"
    And I fill in "State/Province/Region" with "PERF"
    And I fill in "ZIP/Postal Code" with "PERF"
    And I select "Cash" from "Payment type"

    And I press "Place Order"
