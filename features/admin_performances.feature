Feature: Admins can manage performances
  As an administrator
  I want to create / edit and delete performances records

  Background:
    Given a sample theater exists
    And I am an Administrator
    And I am logged in
    And I go to the admin production detail page for "Production One"

  @wip
  Scenario: There is a performances link on the Productions Page
    Given I go to the admin production detail page for "Production One"
    Then I should see "PERF"

  Scenario: There is a New Performance link on the Performance Listing Page
    Given I go to the admin production detail page for "Production One"
    Then I should see "Add performance"

  Scenario: Add a performance (All fields)
    Given I follow "Add performance"
    And I enter a performance on "2015-01-01" with code "PERF1"
    When I press "Create"
    Then I should see "Performance was successfully created."

  Scenario: There cannot be more than one performance at the same time
    Given I follow "Add performance"
    And I enter a performance on "2015-01-01" with code "PERF1"
    And I press "Create"
    And I should see "Performance was successfully created."
    And I go to the admin production detail page for "Production One"
    And I follow "Add performance"
    And I enter a performance on "2015-01-01" with code "PERF2"
    When I press "Create"
    Then I should see "has already been taken"

  Scenario: The box office user can duplicate a performance
    Given I follow "Add performance"
    And I enter a performance on "2015-01-01" with code "PERF1"
    And I press "Create"
    And I should see "Performance was successfully created."
    And I go to the admin production detail page for "Production One"
    And I follow "duplicate_PERF1"
    And I change "Performance code" to "PERF2"
    And I enter a performance date of "2015-01-02"
    When I press "Create"
    Then I should see "Performance was successfully created"
    And I should see "PERF1"
    And I should see "PERF2"
