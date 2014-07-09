Feature: An administrator can add production details to a theater
  Given a theater has been created
  As a StageMgr box office user
  I want to create / edit and delete production records

  Background:
    Given a theater "Theater One" exists
      And a venue "Space 1" exists
    And I am a box office user
    And I am logged in
    And I go to the home page
    And I follow "Theaters"
    And I follow "Theater One"

  Scenario: Add a production (Minimum Required fields)
  Given I follow "Add production"
    And I enter a production with code "TEST" and a capacity of "300"
   When I press "Create"
   Then I should see "Production was successfully created."

  Scenario: Add a production (All fields)
  Given I follow "Add production"
    And I enter a complete production with code "TEST"
   When I press "Create"
   Then I should see "Production was successfully created."

  Scenario: Add a production (check valid values for select boxes)
  Given I follow "Add production"
    And all production status values are presented

  Scenario: Don't delete productions
  Given a production "Production One" exists
    And I go to the admin detail page for theater "Theater One"
    And I should see "Production One"
    Then I should not see "Destroy"

  Scenario: Edit a production
  Given a production "Production One" exists
    And I go to the admin detail page for theater "Theater One"
    And I follow "Edit"
    And I change "Name" to "Production One (Changed)"
   When I press "Update"
   And show me the page
   Then I should see "Production One (Changed)"

  Scenario: Production calls to action
  Given a production "Production One" exists
    And I go to the admin production edit page for "Production One"
    And I change "Calendar Call to Action" to "*Visit* [a test page](http://www.mytest.page)"
    And I press "Update"
    And I go to the box office calendar for production "Production One"
   Then I should see "Visit"
    And I should not see "*Visit*"
    And a link exists to "http://www.mytest.page"
