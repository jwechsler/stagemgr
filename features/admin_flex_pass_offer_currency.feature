Feature: Admin manages flex pass offers with currency fields
  As an administrator
  I want to create and update flex pass offers with decimal values
  So that I can properly set prices and payout amounts

  Background:
    Given I am logged in as an administrator
    And there is a theater named "Test Theater"

  Scenario: Creating a flex pass offer with decimal values
    When I go to the new admin flex pass offer page
    And I fill in "Name" with "Summer Pass 2024"
    And I select "Test Theater" from "Theater"
    And I fill in "Price" with "99.99"
    And I fill in "Facility fee" with "2.50"
    And I fill in "Spiff" with "1.75"
    And I fill in "Flat payout" with "5.25"
    And I fill in "Number of tickets" with "10"
    And I fill in "Months till expiration" with "12"
    And I fill in "Use ticket class code" with "PASS"
    And I check "Active"
    And I press "Create Flex pass offer"
    Then I should see "Summer Pass 2024"
    And I should see "$99.99"
    And I should see "$2.50"
    And I should see "$1.75"
    And I should see "$5.25"

  Scenario: Updating a flex pass offer with decimal values
    Given there is a flex pass offer named "Basic Pass"
    When I go to the edit admin flex pass offer page for "Basic Pass"
    And I fill in "Price" with "149.99"
    And I fill in "Facility fee" with "3.50"
    And I fill in "Spiff" with "2.25"
    And I fill in "Flat payout" with "7.75"
    And I press "Update Flex pass offer"
    Then I should see "$149.99"
    And I should see "$3.50"
    And I should see "$2.25"
    And I should see "$7.75"

  Scenario: Validation prevents negative values
    When I go to the new admin flex pass offer page
    And I fill in "Name" with "Invalid Pass"
    And I select "Test Theater" from "Theater"
    And I fill in "Price" with "-10.00"
    And I fill in "Facility fee" with "-2.50"
    And I fill in "Spiff" with "-1.75"
    And I fill in "Flat payout" with "-5.25"
    And I fill in "Number of tickets" with "10"
    And I fill in "Months till expiration" with "12"
    And I fill in "Use ticket class code" with "PASS"
    And I press "Create Flex pass offer"
    Then I should see "must be greater than or equal to 0"
    And I should not see "Flex pass offer was successfully created"

  Scenario: Decimal precision is maintained
    When I go to the new admin flex pass offer page
    And I fill in "Name" with "Precision Test Pass"
    And I select "Test Theater" from "Theater"
    And I fill in "Price" with "10.999"
    And I fill in "Facility fee" with "2.333"
    And I fill in "Spiff" with "1.777"
    And I fill in "Flat payout" with "5.444"
    And I fill in "Number of tickets" with "10"
    And I fill in "Months till expiration" with "12"
    And I fill in "Use ticket class code" with "PASS"
    And I check "Active"
    And I press "Create Flex pass offer"
    Then I should see "Precision Test Pass"
    And I should see "$11.00"
    And I should see "$2.33"
    And I should see "$1.78"
    And I should see "$5.44"