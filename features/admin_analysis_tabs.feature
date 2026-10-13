Feature: Admin analysis tabs
  As a StageMgr administrator
  I want each production analysis on its own tab
  So I can go straight to the analysis I need

  Background:
    Given a theater "Theater One" exists
      And a venue "Space 1" exists
      And a production "Alpha Show" exists
      And I am an administrator
      And I am logged in
      And I go to the home page
      And I follow "Analysis"

  Scenario: Move between the production analysis tabs
    Then I should see "Rate of Sales Analysis"
    And the "Run analysis" button should be disabled
    When I follow "Ticket Revenue"
    Then I should see "Ticket Revenue Analysis"
    And the "Run analysis" button should be disabled
    When I follow "Audience"
    Then I should see "Audience Analysis"
    And the "Run analysis" button should be disabled
