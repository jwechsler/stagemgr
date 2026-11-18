@javascript
Feature: A patron orders general-admission tickets on the public order page
  As a patron buying general-admission tickets
  I want Review Order to work on the public page
  So that a double click does not submit my order twice

  # The public order layout includes the frontend bundle (jQuery, jquery_ujs,
  # Foundation, reveal_confirm); a general-admission page adds no seat picker.
  Background:
    Given a sample theater exists

  Scenario: Review Order is disabled while the order is submitted
    When I go to new web order for production "Production One" and performance "TEST01"
    Then the order page loads frontend.js once and no seat, admin or application bundle
    When I enter my contact information
    And I select "2" from "ticket_order_ticket_line_items_attributes_2_ticket_count"
    And I enter a valid credit card as payment
    And I press "Review Order" with the form's submission held back
    Then jquery_ujs has disabled the "Review Order" button
    When I release the held-back form and press "Review Order"
    And I press "Order Tickets"
    Then I should see "$10.00"
    And I should see "Your ticket reservation has been made"
