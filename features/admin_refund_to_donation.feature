@javascript
Feature: Box office converts a processed ticket order to a donation
  As a box office user helping a patron who gives up their tickets
  I want Refund to Donation to ask first and then convert the order once
  So that one OK makes exactly one donation and moves the payment once

  # A reserved-seating processed order: its page loads reseating.js beside
  # the layout's application bundle, and must carry one copy of jQuery and
  # jquery_ujs. Refund to Donation is a data-method POST link that jquery_ujs
  # turns into a hidden form; one OK must submit it exactly once.
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
    And the page loads the application bundle once and reseating.js carries only its own code

  Scenario: Confirming converts the order to a donation once
    Given I count the requests that convert an order to a donation
    When I follow "Refund to Donation"
    Then the page has one confirmation dialog, asking "Convert this order to a donation?"
    When I answer the open confirmation "Convert this order to a donation?" with OK
    Then the new donation order's page opens
    And exactly one request converted the order to a donation
    And the order has been converted to exactly one donation
