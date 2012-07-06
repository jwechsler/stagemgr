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
  Given I create a ticket order
  Then I should see "Order was successfully saved and is now Processed"
