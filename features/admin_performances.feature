Feature: Box office users can manage performances
  As a box office user
  I want to create / edit and delete performances records

  Background:
    Given a sample theater exists
    And I am a box office user
    And I am logged in
    And I go to the admin production detail page for "Production One"

  @javascript
  Scenario: There is a performances link on the Productions Page
    Given I go to the admin production detail page for "Production One"
    Then I should see "TEST"

  Scenario: There is a New Performance link on the Performance Listing Page
    Given I go to the admin production detail page for "Production One"
    Then I should see "Add performance"

  Scenario: Add a performance (All fields)
    Given I follow "Add performance"
    And I enter a performance on "2015-01-01" with code "TEST1"
    When I press "Create"
    Then I should see "Performance TEST1 was successfully created."

  Scenario: There cannot be more than one performance at the same time
    Given I follow "Add performance"
    And I enter a performance on "2015-01-01" with code "TEST1"
    And I press "Create"
    And I should see "Performance TEST1 was successfully created."
    And I go to the admin production detail page for "Production One"
    And I follow "Add performance"
    And I enter a performance on "2015-01-01" with code "TEST2"
    When I press "Create"
    Then I should see "has already been taken"

  @javascript
  Scenario: The box office user can duplicate a performance
    Given I follow "Add performance"
    And I enter a performance on "2015-01-01" with code "TEST1"
    And I press "Create"
    And I should see "Performance TEST1 was successfully created."
    And I go to the admin production detail page for "Production One"
    And I follow "duplicate_TEST1"
    And I change "Performance code" to "TEST2"
    And I enter a performance date of "2015-01-02"
    When I press "Create"
    Then I should see "Performance TEST2 was successfully created"
    And I should see "TEST1"
    And I should see "TEST2"
    And the performance date for "TEST2" is "2015-01-02"

  @javascript
  Scenario: The box office user can record trigger criteria
    Given I follow "Add performance"
      And I enter a performance on "2015-01-01" with code "TEST1"
      And I enter a trigger to "SECRET" based on capacity of "50" for the 5th ticket class
      And I enter a trigger to "SECRET" based on "2" days before for the 5th ticket class
      And I press "Create"
      Then I should see "Performance TEST1 was successfully created"
      Then I follow "TEST1"
      Then I should see "will be replaced by SECRET when capacity at or over 50% or 2 days before performance"

  @javascript
  Scenario: The box office user can create custom performance features
    Given I follow "Add performance"
      And I enter a performance on "2015-01-01" with code "TEST1"
      And I enter a custom feature description of "Special Silent Performance"
      And I enter a custom feature email of "This performance *will* be entirely mimed"
      And I press "Create"
     Then I should see "Performance TEST1 was successfully created"
     Then I follow "TEST1"
     Then I should see "Special Silent Performance"
      And I should see "entirely mimed"

  @javascript
  Scenario: The box office user can override sales links for a particular performance
    Given I go to the admin performance edit page for production "Production One" and performance "TEST01"
      And I enter an override URL of "http://testsite.com/specialperformance"
      And I press "Update"
      And I go to the box office calendar for production "Production One"
      And show me the page
     Then I should see a link "6:00PM" to "http://testsite.com/specialperformance"


