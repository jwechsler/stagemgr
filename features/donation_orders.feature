Feature: Donations
  In order to make a donation
  As a web site user
  I want to make a donation via the web
  Background:
    Given the system accepts currency


  Scenario: Make a preselected donation
    Given I go to new donation order
      And I enter my contact information
      And I enter a valid credit card as payment
      And I choose the "Friend" donation level
      And I press "Make a donation"
     Then I should see "Order was successfully saved"
      And I should see "$25.00"

  Scenario: Make a custom donation
    Given I go to new donation order
      And I enter my contact information
      And I enter a valid credit card as payment
      And I enter "40.50" as a donation amount
      And I press "Make a donation"
     Then I should see "Order was successfully saved"
      And I should see "$40.50"

  @wip
  Scenario: Make a monthly pledge
    Given I go to new monthly pledge
      And I enter my contact information
      And I enter a valid credit card as payment
      And I enter "10" as a monthly pledge amount
      And I press "Make a pledge"
     Then I should see "$120.00 over the coming year ($10.00/month)"
      And I should see "Processed"
@wip
  Scenario: Make a monthly pledge with a correction
    Given I go to new monthly pledge
      And I enter my contact information incorrectly
      And I enter a valid credit card as payment
      And I enter "10" as a monthly pledge amount
      And I press "Make a pledge"
      And I should see "There was a problem"
      And I enter my contact information
      And I press "Make a pledge"
     Then I should see "$120.00 over the coming year ($10.00/month)"
      And I should see "Processed"