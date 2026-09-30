@javascript
Feature: A double click on a seat's ticket type reserves the seat once
  As a patron or box office user picking reserved seats
  I want a double click on a ticket type to count as one click
  So that my order gets one ticket for the seat, not a duplicate

  Background:
    Given a theater with reserved seating exists
    And a test performance "PROD01A" exists
    And the seat map for "Production One" is plotted

  Scenario: Public checkout
    Given "ADULT" tickets are sold online with public credit card payments
    When I go to new web order for production "Production One" and performance "PROD01A"
    And I count seat reserve requests
    And I double-click "Adult" for an open seat
    Then the seat has one ticket row and one reserve request was sent
    When I enter my contact information
    And I enter a valid credit card as payment
    And I press "Review Order"
    Then the picked seat has one line item on the order

  Scenario: Box office Add to Order
    Given a processed order for 2 "ADULT" seats at "PROD01A" paid in cash
    And I am a box office user
    And I am logged in
    When I visit the admin page for that order
    And I follow "Add to Order"
    Then the order's current seats show as taken on the seat map
    When I count seat reserve requests
    And I double-click "Adult" for an open seat
    Then the seat has one ticket row and one reserve request was sent
    When I select "Cash" from "Pay using"
    And I uncheck "Email updated confirmation to patron"
    And I place the order and confirm
    Then I should see "Added to order #"
    And the picked seat has one line item on the order

  Scenario: Public checkout ignores repeat clicks while a reserve is in flight
    Given "ADULT" tickets are sold online with public credit card payments
    When I go to new web order for production "Production One" and performance "PROD01A"
    And I hold seat requests
    And I pick "Adult" for open seat 1
    Then 1 seat request is held
    When I click open seat 1 and its "Adult" button again
    Then 1 seat request is held
    And open seat 1 is pending
    When I let held request 1 through
    Then open seat 1 has one ticket row
    And open seat 1 is not pending
    When I enter my contact information
    And I enter a valid credit card as payment
    And I press "Review Order"
    Then the picked seat has one line item on the order

  Scenario: Public checkout handles reserves that answer out of order
    Given "ADULT" tickets are sold online with public credit card payments
    When I go to new web order for production "Production One" and performance "PROD01A"
    And I hold seat requests
    And I pick "Adult" for open seat 1
    And I pick "Adult" for open seat 2
    Then 2 seat requests are held
    When I let held request 2 through
    Then open seat 2 has one ticket row
    When I let held request 1 through
    Then open seat 1 has one ticket row
    And the ticket rows name open seats 1 and 2 once each

  Scenario: Public checkout recovers from a rejected reserve
    Given "ADULT" tickets are sold online with public credit card payments
    When I go to new web order for production "Production One" and performance "PROD01A"
    And I hold seat requests
    And I pick "Adult" for open seat 1
    Then 1 seat request is held
    When I reject held request 1 with status 422 and message "Seat A1 is not available for your ticket type"
    Then an alert said "Seat A1 is not available for your ticket type"
    And open seat 1 is not pending
    And open seat 1 has no ticket rows
    And open seat 1 is still open
    When I pick "Adult" for open seat 1
    Then 1 seat request is held

  Scenario: Box office Add to Order ignores repeat clicks while a reserve is in flight
    Given a processed order for 2 "ADULT" seats at "PROD01A" paid in cash
    And I am a box office user
    And I am logged in
    When I visit the admin page for that order
    And I follow "Add to Order"
    Then the order's current seats show as taken on the seat map
    When I hold seat requests
    And I pick "Adult" for open seat 1
    Then 1 seat request is held
    When I click open seat 1 and its "Adult" button again
    Then 1 seat request is held
    And open seat 1 is pending
    When I let held request 1 through
    Then open seat 1 has one ticket row
    When I select "Cash" from "Pay using"
    And I uncheck "Email updated confirmation to patron"
    And I place the order and confirm
    Then I should see "Added to order #"
    And the picked seat has one line item on the order
