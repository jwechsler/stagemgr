qFeature: Membership Administration
  In order to manage memberships on the back end
  As a box office user and administrator
  I want to manage memberships

  Background:
    Given a sample theater exists
      And a membership offer "Monthly Membership" exists

  Scenario: The Admin page has a link to manage membership offers
    Given I am a box office user
      And I am logged in
      And I go to the home page
     Then "Membership Offers" should link to "the admin membership offers page"

  Scenario: Only administrators and box office users can manage membership offers and orders
    Given I am a theater user
      And I am logged in
      And I go to the home page
     Then I should not see "Membership Offers"

  Scenario: Non-box office staff can't create membership offers
    Given I am a theater user
      And I am logged in
      And I go to the new admin membership offer page
     Then I should see "You are not authorized to access this page"

  Scenario: Only administrators can create membership offers
    Given I am an Administrator
      And I am logged in
     When I go to the admin membership offers page
      And I follow "New Membership Offer"
      And I enter a membership offer "Monthly Alternate"
      And I press "Create Membership offer"
     Then I should see "Monthly Alternate"
      And I should see "Successfully created"

  @javascript
  Scenario: Box office users can only view and add orders
    Given I am a box office user
      And I am logged in
     When I go to the admin membership offers page
     Then I should see "Monthly Membership"
      And I should see "Create Order"
      And I should not see "Edit"
      And I should not see "Destroy"
      And I should not see "New Membership Offer"

  Scenario: Box office personnel can place membership orders
    Given I am a box office user
      And I am logged in
      And I go to the new admin membership order page for offer "Monthly Membership"
      And I enter my contact information
      And I enter a valid credit card as payment
      And I press "Place Order"
     Then I should see "Customer successfully set up for the Monthly Membership payment plan"

  Scenario: Administrators can create trial memberships
    Given I am an administrator
      And I am logged in
      And I go to the new admin membership offer page
      And I enter a membership offer "Trial Membership"
      And I fill in "Trial Periods" with "1"
      And I fill in "Trial Price" with "0.00"
      And I check "First time members only"
      And I press "Create Membership offer"
     Then I should see "Trial Membership"
      And I should see "Successfully created"
      And a membership_offer should exist with trial_period of 1

  Scenario: Box office personnel can place membership gift orders
    Given I am a box office user
      And I am logged in
     When I go to the new admin membership order page for offer "Monthly Membership"
      And I enter my contact information
      And I enter a valid credit card as payment
      And I check "Give as a gift"
      And I enter a gift recipient
      And I press "Place Order"
    Then a membership exists with status "Active"
      And a membership order exists with a gift recipient "Gift Getter"
      # And a membership order exists for "Ticket Buyer"
      And an address "Ticket Buyer" exists
      And an address "Gift Getter" exists
    And I should see "Customer successfully set up for the Monthly Membership payment plan"

  Scenario: Members can specify requested seating
    Given I am a box office user
      And I am logged in
     When I go to the new admin membership order page for offer "Monthly Membership"
      And I enter my contact information
      And I enter a valid credit card as payment
      And I prefer "Front row" seating
      And I press "Place Order"
     Then a membership exists with status "Active"
      #And a membership order exists for "Ticket Buyer"
      #And a membership exists with "Front row" as preferred seating

  Scenario: Administrators can set a flag to prevent public sales
    Given I am an administrator
      And I am logged in
    When I go to the admin edit page for membership offer "Monthly Membership"
     And I uncheck "On sale to public"
     And I press "Update Membership offer"
    Then I should see "Private"
     And I go to the new membership order for membership offer "Monthly Membership"
    Then I should see "You have been directed to a page that is not active."
    Then I go to the admin edit page for membership offer "Monthly Membership"
     And I check "On sale to public"
     And I press "Update Membership offer"
     And I go to the new membership order for membership offer "Monthly Membership"
    Then I should not see "is not active"
