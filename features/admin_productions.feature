@wip
Feature: An administrator can add production details to a theater
  Given a theater has been created
  As a StageMgr Admin user
  I want to create / edit and delete production records

  Background:
    Given a theater "Theater One" exists
      And a venue "Space 1" exists
    And I am an Administrator
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

  Scenario: Delete a production
  Given a production "Production One" exists
    And I go to the admin detail page for theater "Theater One"
    And I should see "Production One"
    When I follow "Destroy"
    Then I should not see "Production One"


  Scenario: Edit a production
  Given a production "Production One" exists
    And I go to the admin detail page for theater "Theater One"
    And I follow "Edit"
    And I change "Name" to "Production One (Changed)"
   When I press "Update"
   Then I should see "Production One (Changed) was successfully updated."
