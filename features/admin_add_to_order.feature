@javascript
Feature: Add to Order
  As a box office user
  I want to add a captioning tablet and an extra seat to a processed order
  So that the patron keeps their seats and pays only for the new items

  Background:
    Given a theater with reserved seating exists
    And a test performance "PROD01A" exists
    And the seat map for "Production One" is plotted
    And a "Captioning tablet" add-on costing 5 is on sale for "PROD01A"
    And a processed order for 2 "ADULT" seats at "PROD01A" paid in cash
    And I am a box office user
    And I am logged in

  Scenario: Add a tablet and one more seat, paid in cash
    When I visit the admin page for that order
    And I follow "Add to Order"
    Then the order's current seats show as taken on the seat map
    When I add the "Captioning tablet" add-on
    And I pick an open seat as "Adult"
    Then the order total should be "$30.00"
    When I select "Cash" from "Pay using"
    And I uncheck "Email updated confirmation to patron"
    And I place the order and confirm
    Then I should see "Added to order #"
    And I should see "Captioning tablet"
    And the order's history records the addition, which is gone
    And the order should have 1 "Captioning tablet" and 3 "Adult" tickets
    And the order's original seats are unchanged and the new seat is assigned
