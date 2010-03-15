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
  
  @wip
  Scenario: Delete a production
  Given the following productions exist:
  | name             |
  | Production One   |
    And I go to the admin theater edit page for production "Production One"
    And I follow "Destroy"
    And I hit "OK" on the popup
    And I should not see "Production One"

  Scenario: Edit a production
  Given the following productions exist:
  | name             |
  | Production One   |
    And I go to the admin theater detail page for production "Production One"
    And I follow "Production One" "Edit" link
    And I fill in "Name" with "Production One (Changed)"
    And I fill in "Credit lines" with "Lorem ipsum"
    And I select 01/01/2005 from "First preview at"
    And I select 01/01/2005 from "Press opening at"
    And I select 01/01/2005 from "Opening at"
    And I select 01/01/2005 from "Closing at"
    And I fill in "Show description" with "<h1>Hello</h1>"
    And I fill in "Capacity" with "300"
    And I fill in "Additional information link" with "http://google.com"
    And I select "Inactive" from "Status"
   When I press "Update"
   Then I should see "Production was successfully updated."
    And I should see "Production One (Changed)"

  Scenario: View a production
  Given the following productions exist:
  | name             | credit_lines  | first_preview_at | press_opening_at | opening_at | closing_at | show_description | capacity | additional_information_link | status   |
  | Production One   | cline1        | 01/10/2005       | 01/11/2005       | 01/12/2005 | 01/13/2005 | descriptive      | 300      | http://www.google.com       | Inactive |
    And I go to the admin theater detail page for production "Production One"
    And I follow "Production One"
    And I should see "Production One"
    And I should see "descriptive"
    And I should see "300"
    And I should see "Inactive"
    And I should see "http://www.google.com"
    And I should see "cline1"
    And I should see "2005-01-10"
    And I should see "2005-01-11"
    And I should see "2005-01-12"
    And I should see "2005-01-13"

