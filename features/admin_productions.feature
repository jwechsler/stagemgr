Feature: An administrator can perform privileged production operations
  Given a theater has been created
  As an Administrator
  I want to delete production records

  Background:
    Given a theater "Theater One" exists
      And a venue "Space 1" exists
    And I am an administrator
    And I am logged in
    And I go to the home page
    And I follow "Theaters"
    And I follow "Theater One"

  Scenario: Delete a production
  Given a production "Production One" exists
    And I go to the admin detail page for theater "Theater One"
    And I should see "Production One"
    When I follow "Destroy"
    Then I should not see "Production One"
