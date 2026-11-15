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

  Scenario: Finalizing sends no rollback request
    Given a processed order for 2 "ADULT" seats at "PROD01A" paid in cash
    And I am a box office user
    And I am logged in
    When I visit the admin page for that order
    And I record the page's seating requests
    And I open Change Seating
    And I move the order's first seat to an open seat
    And I finalize the new seating
    Then Change Seating has closed
    And a commit request was sent
    And no rollback request was sent
    And the first seat's line item holds the new seat
    And the old seat is available with no line item on it

  Scenario: Closing without finalizing rolls the change back
    Given a processed order for 2 "ADULT" seats at "PROD01A" paid in cash
    And I am a box office user
    And I am logged in
    When I visit the admin page for that order
    And I record the page's seating requests
    And I open Change Seating
    And I move the order's first seat to an open seat
    Then the move is pending
    When I close Change Seating without finalizing
    Then a rollback request was sent
    And the old seat is back on the order and the new seat is open again

  Scenario: Pressing Esc rolls the change back
    Given a processed order for 2 "ADULT" seats at "PROD01A" paid in cash
    And I am a box office user
    And I am logged in
    When I visit the admin page for that order
    And I record the page's seating requests
    And I open Change Seating
    And I move the order's first seat to an open seat
    Then the move is pending
    When I press Esc in Change Seating
    Then a rollback request was sent
    And the old seat is back on the order and the new seat is open again

  Scenario: A second change on the same page still rolls back after an earlier finalize
    Given a processed order for 2 "ADULT" seats at "PROD01A" paid in cash
    And I am a box office user
    And I am logged in
    When I visit the admin page for that order
    And I record the page's seating requests
    And I open Change Seating
    And I move the order's first seat to an open seat
    And I finalize the new seating
    Then Change Seating has closed
    And no rollback request was sent
    When I open Change Seating again
    And I move the new seat to another open seat
    Then the second move is pending
    When I close Change Seating without finalizing
    Then a rollback request was sent
    And the second move was rolled back, keeping the first

  Scenario: Reopening after a cancelled change shows the seats as they were
    Given a processed order for 2 "ADULT" seats at "PROD01A" paid in cash
    And I am a box office user
    And I am logged in
    When I visit the admin page for that order
    And I record the page's seating requests
    And I open Change Seating
    And I move the order's first seat to an open seat
    And I close Change Seating without finalizing
    Then a rollback request was sent
    And the old seat is back on the order and the new seat is open again
    When I open Change Seating again
    Then Change Seating shows the order's original seating

  Scenario: A change made after a cancelled one finalizes correctly
    Given a processed order for 2 "ADULT" seats at "PROD01A" paid in cash
    And I am a box office user
    And I am logged in
    When I visit the admin page for that order
    And I record the page's seating requests
    And I open Change Seating
    And I move the order's first seat to an open seat
    And I close Change Seating without finalizing
    Then a rollback request was sent
    And the old seat is back on the order and the new seat is open again
    When I open Change Seating again
    Then Change Seating shows the order's original seating
    When I move the order's first seat to an open seat
    And I finalize the new seating
    Then the first seat's line item holds the new seat
    And the old seat is available with no line item on it
    And the order page shows the new seat location

  Scenario: Reopening after a finalize shows the new seating
    Given a processed order for 2 "ADULT" seats at "PROD01A" paid in cash
    And I am a box office user
    And I am logged in
    When I visit the admin page for that order
    And I open Change Seating
    And I move the order's first seat to an open seat
    And I finalize the new seating
    Then Change Seating has closed
    When I open Change Seating again
    Then Change Seating shows the new seating

  Scenario: Dismissing a notice keeps the pending change
    Given a processed order for 2 "ADULT" seats at "PROD01A" paid in cash
    And I am a box office user
    And I am logged in
    When I visit the admin page for that order
    And I record the page's seating requests
    And I open Change Seating
    And I move the order's first seat to an open seat
    And I pick one more open seat than the order has tickets
    Then I dismiss the notice "You can only assign 2 seats"
    And Change Seating is still open
    And the move is pending
    And no rollback request was sent
