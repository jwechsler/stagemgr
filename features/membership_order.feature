Feature: Membership Ordering
  As a web site user
  I want to be able to buy a membership
  Background:
    Given a membership offer "Test Membership" exists
    And the system accepts currency

  Scenario: Create a membership
    Given I go to new membership order for membership offer "Test Membership"
    And I enter my contact information
    And I enter a valid credit card as payment
    And I prefer "Best available (center)" seating
    And I press "Checkout"
    Then I should see "You've been successfully set up for the Test Membership payment plan."
     And a membership exists with status "Active"
     And a membership exists with "Best available (center)" as preferred seating

  Scenario: Create a gift membership
    Given I go to new membership order for membership offer "Test Membership"
    And I check "Give as a gift"
    And I enter my contact information
    And I enter a gift recipient
    And I enter a valid credit card as payment
    And I press "Checkout"
    Then a membership exists with status "Active"
      And a membership order exists with a gift recipient "Gift Getter"
      And a membership order exists for "Ticket Buyer"
      And an address "Ticket Buyer" exists
      And an address "Gift Getter" exists
      And I should see "We're processing your membership order for Gift Getter"
