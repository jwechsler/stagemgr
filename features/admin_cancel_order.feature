@javascript
Feature: Box office cancels a held ticket order
  As a box office user
  I want Cancel Order to ask first, with Cancel as the default answer
  So that a stray Enter never cancels an order

  # A held order is editable, so its admin page is the edit form with the
  # seat map (the seat map needs a plotted image to render). That page loads
  # seat_assignment.js, which bundles application.js a second time, so the
  # data-method Cancel Order link is answered on a double-jQuery page.
  Background:
    Given a theater with reserved seating exists
    And a test performance "PROD01A" exists
    And the seat map for "Production One" is plotted
    And the performance "PROD01A" has 2 held seats with a valid HOLD order
    And I am a box office user
    And I am logged in
    When I visit the admin page for the held order
    Then the order page loads seat_assignment.js

  Scenario: Cancel is the default, so Enter leaves the order alone
    When I follow "Cancel Order"
    Then the confirmation "Are you sure?" defaults to Cancel
    And the confirmation's accept button reads "OK"
    When I press Enter in the confirmation
    Then the held order is still on hold

  Scenario: Cancelling the question leaves the order alone
    When I follow "Cancel Order" and cancel
    Then the held order is still on hold

  Scenario: Confirming cancels the order once
    When I follow "Cancel Order" and confirm with "OK"
    Then the held order has been cancelled once
    And the performance "PROD01A" should have 0 held seats with valid orders
