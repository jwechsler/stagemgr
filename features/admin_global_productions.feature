Feature: Global productions list and picker
  As a StageMgr user
  I want a Productions section in the top bar
  So I can reach any production I have access to without going through a theater

  Background:
    Given a theater "Theater One" exists
      And a venue "Space 1" exists
      And a production "Alpha Show" exists
      And a theater "Theater Two" exists
      And a production "Beta Show" exists

  @javascript
  Scenario: Administrator sees productions across all theaters
    Given I am an administrator
    And I am logged in
    And I go to the home page
    When I follow "Productions"
    And I wait for the datatable to load
    Then I should see "Alpha Show"
    And I should see "Beta Show"
    And I should see "Theater Two"

  @javascript
  Scenario: Theater user only sees productions for granted theaters
    Given I am a theater user
    And I am logged in
    And I go to the home page
    When I follow "Productions"
    And I wait for the datatable to load
    Then I should see "Alpha Show"
    And I should not see "Beta Show"

  @javascript
  Scenario: Pick a production via the reports typeahead
    Given I am an administrator
    And I am logged in
    And I go to the home page
    And I follow "Reports"
    When I search the production picker in "form[action*='production_sales_by_performance']" for "Alpha"
    And I choose "Alpha Show" from the production picker suggestions
    Then the production picker in "form[action*='production_sales_by_performance']" should show "Alpha Show"

  @javascript
  Scenario: Drill into a theater group to pick one production
    Given I am an administrator
    And I am logged in
    And I go to the home page
    And I follow "Reports"
    When I search the production picker in "form[action*='production_sales_by_performance']" for "Theater Two"
    And I choose "All shows by Theater Two" from the production picker suggestions
    And I choose "Beta Show" from the production picker suggestions
    Then the production picker in "form[action*='production_sales_by_performance']" should show "Beta Show"
