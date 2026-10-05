Feature: Membership analysis
  As a StageMgr administrator
  I want to analyze membership offers over a date range
  So I can see what each offer brings in and what members redeem

  Background:
    Given a membership offer "Wit Membership" exists
      And there is an inactive membership offer named "Wit Legacy"
      And I am an administrator
      And I am logged in
      And I go to the home page
      And I follow "Analysis"
      And I follow "Pass Sales"

  @javascript
  Scenario: Inactive offers are suggested, labelled and listed after active ones
    When I search the offer picker in "#membership-analysis-form" for "Wit"
    Then I should see the offer picker suggestions "Wit Membership, Wit Legacy (Inactive)"

  @javascript
  Scenario: Removing an offer clears the results until the next run
    Given I have run the membership analysis for "Wit Membership" and "Wit Legacy"
    When I remove "Wit Legacy" from the offer picker in "#membership-analysis-form"
    Then I should not see the membership analysis results
    When I press "Run"
    Then I should see the membership analysis results

  @javascript
  Scenario: Changing a date clears the results until the next run
    Given I have run the membership analysis for "Wit Membership" and "Wit Legacy"
    When I change the membership analysis start date to "2026-02-01"
    Then I should not see the membership analysis results
