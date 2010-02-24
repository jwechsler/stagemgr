Feature: An administrator can add production details to a theater
  Given a theater has been created
  As a StageMgr Admin user
  I want to create / edit and delete production records

  Background:
    Given the following theaters exist:
    | name          |
    | Theater One   |
    And I am an Administrator
    And I am logged in
    And I go to the home page
    And I follow "Theaters"
    And I follow "Theater One"

  Scenario: Add a production (Minimum Required fields)
  Given I follow "Add production"
    And I fill in "Name" with "New Production"
   When I press "Create"
   Then I should see "Production was successfully created."

  Scenario: Add a production (All fields)
  Given I follow "Add production"
    And I fill in "Name" with "New Production"
    And I fill in "Credit lines" with "Lorem ipsum"
    And I select 01/01/2005 from "First preview at"
    And I select 01/01/2005 from "Press opening at"
    And I select 01/01/2005 from "Opening at"
    And I select 01/01/2005 from "Closing at"
    And I fill in "Show description" with "<h1>Hello</h1>"
    And I fill in "Capacity" with "300"
    And I fill in "Additional information link" with "http://google.com"
    And I select "Active" from "Status"
   When I press "Create"
   Then I should see "Production was successfully created."

  Scenario: Add a production (check valid values for select boxes)
  Given I follow "Add production"
  	And I select "Active" from "Status"
  	And I select "Inactive" from "Status"

  Scenario: Add a production (Name Required)
  Given I follow "Add production"
   When I press "Create"
   Then I should see "Name can't be blank"
  
  Scenario: Delete a production
    When the user sees a delete link next to each production
      And the user clicks on that link
      And the user confirms the delete
      And the production has no associated peformances
    Then the production is deleted.

  Scenario: Edit a production
    Given the user has the edit production privilege
    When the adminstrator visits the theater detail page
      And clicks on a production link
    Then the system allows the user to edit Name | Credit Lines (text) | First Preview (date) | Press Opening (date) | Opening (date) | Closing (date) | Show description (html) | Capacity | Additional Information (link) | Status (Active/Inactive)
    
  Scenario: View a production
    Given the user is associated with a theater
    When the user visits the theater detail page
      And clicks on a theater name
    Then the production detail screen is presented
      And I should see all defined field values for that production

