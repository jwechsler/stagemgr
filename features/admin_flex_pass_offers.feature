@javascript
Feature: Flex Pass Box Office Ordering
  As an box office user
  I want to enter orders for a flex pass
  Background:
    Given a sample theater exists
    And the system accepts flex passes
    And I am a box office user
    And I am logged in

  Scenario: Navigate to flex pass offer order page 
    Given I visit the admin flex pass offer page
      And I follow "Create Order"
      And I should see "NEW ORDER"

  Scenario: Place a flex pass order through the back end
    Given I go to the new admin flex pass order page for "Flex Pass"
      And I enter my contact information
      And I enter a valid credit card as payment through the backend
      And I place the order
      And I should see "successfully processed"
