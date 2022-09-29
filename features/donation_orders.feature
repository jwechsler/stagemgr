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
      And I choose the "Wit Club" donation level
      And I press "Make a donation"
      And show me the page
     Then I should see "Order was successfully processed"
      And I should see "$50.00"
  @wip
  Scenario: Make a custom donation
    Given I go to new donation order
      And I enter my contact information
      And I enter a valid credit card as payment
      And I enter "40.50" as a donation amount
      And I press "Make a donation"
     Then I should see "charged your credit card"
      And I should see "$40.50"
  