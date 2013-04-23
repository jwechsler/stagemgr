Feature: Box office ordering
  As an administrator
  I want to create / edit and delete performances records
  Background:
    Given a sample theater exists
    And I am an Administrator
    And I am logged in
    And I go to New Box Office Order

  Scenario: Create a credit card order
    Given I go to new admin ticket order
       And I enter production code "TEST" and performance code "PERF"
       And I enter 2 "CHEAP" tickets
       And I enter my contact information
       And I enter a valid credit card as payment
       And I press "Place Order"
    Then I should see "Order was successfully saved and is now Processed"
