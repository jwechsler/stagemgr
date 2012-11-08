Feature: Membership Ordering
  As a web site user
  I want to be able to buy a membership

  @wip
  Scenario: Create a membership
    Given a membership offer "Test Membership" exists
    And I go to new membership order for membership offer "Test Membership"
    And I enter my contact information
    And I enter a valid credit card as payment
    And I press "Checkout"
    Then I should see "You've been successfully set up for the Test Membership payment plan."
     And a membership exists with status "Active"
     And a membership exists with current status "Pending"

