Feature: Advance sales analysis theater picker
  As a StageMgr administrator
  I want to pick theaters for the advance sales analysis by typing their names
  So I don't have to scroll a long list of every theater

  Background:
    Given a theater "Theater One" exists
      And a venue "Space 1" exists
      And a production "Alpha Show" exists
      And a theater "Theater Two" exists
      And a production "Beta Show" exists
      And I am an administrator
      And I am logged in
      And I go to the home page
      And I follow "Analysis"
      And I follow "Advance Sales"

  @javascript
  Scenario: Pick a theater with the typeahead and run the analysis
    When I search the theater multi picker in "#advance-sales-form" for "Theater O"
    And I choose "Theater One" from the production picker suggestions
    Then the theater multi picker in "#advance-sales-form" should list "Theater One"
    When I press "Run analysis"
    Then I should see "Nothing sold for that selection."
    And the theater multi picker in "#advance-sales-form" should list "Theater One"
    And the theater multi picker in "#advance-sales-form" should not list "Theater Two"
