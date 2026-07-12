Feature: Report offer picker
  As a StageMgr administrator
  I want to limit membership and flex pass reports to selected offers
  So the report covers only the offers I care about

  Background:
    Given a theater "Theater One" exists
      And there is a flex pass offer named "Wit Pass" tagged "Holiday"
      And there is a flex pass offer named "Roving Pass" tagged "Holiday"
      And there is an inactive flex pass offer named "Retired Pass"

  @javascript
  Scenario: Pick flex pass offers by tag for the sales report
    Given I am an administrator
    And I am logged in
    And I go to the home page
    And I follow "Reports"
    When I search the offer picker in "form[action*='flexpass_sales']" for "Holi"
    And I choose "All offers tagged Holiday" from the offer picker suggestions
    Then the offer picker in "form[action*='flexpass_sales']" should list "Wit Pass"
    And the offer picker in "form[action*='flexpass_sales']" should list "Roving Pass"

  @javascript
  Scenario: Remove a selected offer
    Given I am an administrator
    And I am logged in
    And I go to the home page
    And I follow "Reports"
    When I search the offer picker in "form[action*='flexpass_sales']" for "Wit Pass"
    And I choose "Wit Pass" from the offer picker suggestions
    And I remove "Wit Pass" from the offer picker in "form[action*='flexpass_sales']"
    Then the offer picker in "form[action*='flexpass_sales']" should list nothing

  @javascript
  Scenario: Inactive offers are not suggested
    Given I am an administrator
    And I am logged in
    And I go to the home page
    And I follow "Reports"
    When I search the offer picker in "form[action*='flexpass_sales']" for "Retired"
    Then I should see no offer picker suggestions
