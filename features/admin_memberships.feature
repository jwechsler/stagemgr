
Feature: Membership Administration
  In order to manage memberships on the back end
  As a box office user and administrator
  I want to manage memberships

  Background:
    Given the following default_ticket_classes exist:
      | class_code   | class_name     | ticket_price | web_visible | software_managed |
      | MEMBER       | Member Ticket  | 5.00         | false        | true            |
      | MEMBERFRIEND | Friend Ticket  | 0.00         | false        | true            |
     And the following membership_offer exists:
      | name               |
      | Monthly Membership |

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

  Scenario: Non-administrators can't create membership offers
    Given I am a box office user
      And I am logged in
      And I go to the new admin membership offer page
     Then I should see "You are not allowed to access this action"

  Scenario: Only administrators can create membership offers
    Given I am an Administrator
      And I am logged in
     When I go to the admin membership offers page
      And I follow "New Membership Offer"
      And I enter a membership offer "Monthly Alternate"
      And I press "Create Membership offer"
     Then I should see "Monthly Alternate"
      And I should see "Successfully created"


  Scenario: Box office users can only view and add orders
    Given I am a box office user
      And I am logged in
     When I go to the admin membership offers page
     Then I should see "Show"
      And I should not see "Edit"
      And I should not see "Destroy"
      And I should not see "New Membership Offer"
    
  Scenario: Box office personnel can place membership orders from the offers page
    Given I am a box office user
      And I am logged in
     When I go to the admin membership offers page
      And I follow "Create Order"
      And I enter my contact information
      And I enter a valid credit card as payment
      And I press "Checkout"
     Then I should see "Customer successfully set up for the Monthly Membership payment plan"
  
  @wip
  Scenario: Administrators can create trial memberships
    Given I am an administrator
      And I am logged in
      And I go to the new admin membership offer page
      And I enter a membership offer "Trial Membership"
      And I fill in "Trial Periods" with "1"
      And I fill in "Trial Price" with "0.00"
      And I check "Offer restricted to first time members"
      And I press "Create Membership offer"
     Then I should see "Trial Membership"
      And I should see "Successfully created"
      And a membership_offer should exist with trial_period of 1

    

  
