@javascript
Feature: Box office converts a processed ticket order to a donation
  As a box office user helping a patron who gives up their tickets
  I want Refund to Donation to ask first and then convert the order once
  So that one OK makes exactly one donation and moves the payment once

  # A reserved-seating processed order: its page loads reseating.js, which
  # bundles application.js a second time (jQuery, jquery_ujs and
  # reveal_confirm.js evaluated twice). Refund to Donation is a data-method
  # POST link, so both jquery_ujs copies could build and submit its hidden
  # form; the action must still run exactly once.
  Background:
    Given a theater with reserved seating exists
    And a test performance "PROD01A" exists
    And the seat map for "Production One" is plotted
    And a processed order for 2 "ADULT" seats at "PROD01A" paid in cash
    And that order's theater accepts donations
    And I am a box office user
    And I am logged in
    When I visit the admin page for that order
    Then the order page loads reseating.js

  Scenario: Confirming converts the order to a donation once
    Given I count the requests that convert an order to a donation
    When I follow "Refund to Donation"
    Then the page has one confirmation dialog, asking "Convert this order to a donation?"
    When I answer the open confirmation "Convert this order to a donation?" with OK
    Then the new donation order's page opens
    And exactly one request converted the order to a donation
    And the order has been converted to exactly one donation
