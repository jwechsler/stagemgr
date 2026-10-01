@javascript
Feature: Box office changes the seats on a processed order
  As a box office user moving a patron to different seats
  I want Change Seating to move each ticket with its seat
  So that the ticket prints with the new seat and the old seat can be resold

  Background:
    Given a theater with reserved seating exists
    And a test performance "PROD01A" exists
    And the seat map for "Production One" is plotted

  Scenario: Move one of two seats
    Given a processed order for 2 "ADULT" seats at "PROD01A" paid in cash
    And I am a box office user
    And I am logged in
    When I visit the admin page for that order
    And I open Change Seating
    And I move the order's first seat to an open seat
    And I finalize the new seating
    Then the first seat's line item holds the new seat
    And the old seat is available with no line item on it
    And the order page shows the new seat location
