@javascript
Feature: A patron picks reserved seats on the public order page
  As a patron buying tickets for a reserved-seating performance
  I want the seat picker, its notices and Place Order to work on the public page
  So that I can choose my seats and buy them

  # The public order layout has no application bundle; it includes the
  # frontend bundle (one copy each of jQuery, jquery_ujs, Foundation and
  # reveal_confirm), and the page adds seat_assignment, which carries only the
  # seat picker's own code.
  Background:
    Given a theater with reserved seating exists
    And a test performance "PROD01A" exists
    And the seat map for "Production One" is plotted
    And "ADULT" tickets are sold online with public credit card payments
    When I go to new web order for production "Production One" and performance "PROD01A"
    Then the order page loads frontend.js and seat_assignment.js once each and no admin or application bundle
    And the seat picker's libraries are ready on the page's jQuery

  Scenario: Picking a seat and placing the order
    When I pick "Adult" for open seat 1
    Then open seat 1 has one ticket row
    When I enter my contact information
    And I enter a valid credit card as payment
    And I press "Review Order" with the form's submission held back
    Then jquery_ujs has disabled the "Review Order" button
    When I release the held-back form and press "Review Order"
    Then the picked seat has one line item on the order
    When I press "Order Tickets"
    Then I should see "Your ticket reservation has been made"

  Scenario: A seat taken by someone else shows one notice
    When I hold seat requests
    And I pick "Adult" for open seat 1
    Then 1 seat request is held
    When I reject held request 1 with status 422 and message "Sorry, that seat is no longer available"
    Then the page has one notice dialog, saying "Sorry, that seat is no longer available"
    And an alert said "Sorry, that seat is no longer available"
    And open seat 1 has no ticket rows
