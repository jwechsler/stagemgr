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
    Given I go to new donation order
      And I enter my contact information
      And I enter a valid credit card as payment
      And I select the monthly pledge option
      And I enter "10" as a monthly pledge amount
      And I press "Make a donation"
     Then I should see "Your pledge for $120.00 over the coming year ($10/month) has been made."
