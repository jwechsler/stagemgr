Feature: Box office ordering
  As an administrator
  I want to create / edit and delete performances records
  Background:
    Given a theater "Test Theater" exists
    And the system accepts currency
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
    And I am an Administrator
    And I am logged in
    And I go to New Box Office Order

  Scenario: Create a credit card order
    Given I go to new admin ticket order
       And I enter production code "TEST" and performance code "PERF"
       And I enter 2 "CHEAP" tickets
       And I enter my contact information
       And I enter a valid credit card as payment
       And I press "Place Order"
    Then I should see "Order was successfully saved and is now Processed"
