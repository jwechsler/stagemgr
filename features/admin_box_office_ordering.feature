Feature: Box office ordering
  As an box office user
  I want to enter orders
  Background:
    Given a sample theater exists
    And I am a box office user
    And I am logged in
    And the system accepts checks
  Scenario: Create a credit card order
    Given I go to new admin ticket order
      And I enter production code "TEST" and performance code "PERF"
      And I enter 2 "CHEAP" tickets
      And I enter my contact information
      And I enter a valid credit card as payment

      And I press "Place Order"
    Then I should see "Order was successfully saved and is now Processed"

  Scenario: Create a personal check order
    Given I go to new admin ticket order
      And I enter production code "TEST" and performance code "PERF"
      And I enter 2 "CHEAP" tickets
      And I enter my contact information
      And I enter a check number "1224" as payment
      And I press "Place Order"
     Then I should see "Order was successfully saved and is now Processed"
      And I should see "1224"

  Scenario: Create an external payment order
    Given an external payment type "Goldstar" exists
      And I go to new admin ticket order
      And I enter production code "TEST" and performance code "PERF"
      And I enter 2 "CHEAP" tickets
      And I enter my contact information
      And I choose "Goldstar" as payment
      And I press "Place Order"
     Then I should see "Order was successfully saved and is now Processed"

  Scenario: Enforce ticket class requirements from external payment orders
    Given an external payment type "Goldstar" restricted to ticket classes starting with "CHEAP" exists
      And I go to new admin ticket order
      And I enter production code "TEST" and performance code "PERF"
      And I enter 2 "RICH" tickets
      And I enter my contact information
      And I choose "Goldstar" as payment
      And I press "Place Order"
     Then I should see "This payment type is restricted to CHEAP tickets"
      And I enter 2 "CHEAP" tickets
      And I press "Place Order"
      And I should see "Order was successfully saved and is now Processed"

  Scenario: Update note on existing order
    Given a ticket order for performance "PERF" paid with cash exists
      And I go to the admin ticket order detail page
      And I add a note
      And I edit the note to read "Magic Update"
      And I press "Save update"
     Then I should see "Note updated"
      And I should see "Magic Update"

  Scenario: Hold order under name
    Given I go to new admin ticket order
      And I enter production code "TEST" and performance code "PERF"
      And I enter 2 "CHEAP" tickets
      And I enter my contact information
      And I enter a check number "1224" as payment
      And I mark the order as held under "Magic Hold Guy"
      And I press "Place Order"
     Then I should see "Order was successfully saved"
      And I should see "Hold under"
      And I should see "Magic Hold Guy"

