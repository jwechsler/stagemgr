Feature: An administrator can perform privileged production operations
  Given a theater has been created
  As an Administrator
  I want to delete production records
  I want to create a custom label for productions

  Background:
    Given a theater "Theater One" exists
      And a venue "Space 1" exists
    And I am an administrator
    And I am logged in
    And I go to the home page
    And I follow "Theaters"
    And I follow "Theater One"

  @javascript
  Scenario: Delete a production
  Given a production "Production One" exists
    And I go to the admin detail page for theater "Theater One"
    And I should see "Production One"
    When I follow "Destroy"
    Then I should not see "Production One"

  @javascript
  Scenario: Create a custom labelled production
   Given a production "Seminar" exists
     And I go to the admin detail page for theater "Theater One"
     And I follow "Edit"
     And I enter a custom label "Master Class"
     And I press "Update Production"
    Then I should see "Master Class"
