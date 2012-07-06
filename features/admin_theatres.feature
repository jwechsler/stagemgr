
Feature: The Administrator can manage theater records
  In order to create theaters to attach performances and ticket classes to
  As a StageMgr Admin user
  I want to create / edit and delete theater records

  Scenario: There is a 'Theaters' menu link for admins
    Given I am an Administrator
      And I am logged in
     When I go to the home page
     Then I should see a link to '/admin/theaters'

  Scenario: There is not a 'Theaters' menu link for non-admins
  	Given I am not an Administrator
      And I am logged in
     When I go to the home page
     Then I should not see a link to '/admin/theaters'

  Scenario: List theaters as admin
    Given the following theaters exist:
        | name        |
        | ABC Theater |
        | DEF Theater |
	And I am an Administrator
    And I am logged in
    And I go to the home page
    When I go to the admin theater page
    Then I should see "ABC Theater"
     And I should see "DEF Theater"
     And each theater name is a link to a theater detail page
  @wip
  Scenario: Add a theater (Minimum Required fields)
    Given I am an Administrator
      And I am logged in
      And I go to the admin/theater page
      And I follow "New theater"
      And I enter a theater called "Theater Number One"
      And I press "Create"
     Then show me the page
      And I should be on the admin/theater page
      And I should see "Theater Number One"

  Scenario: Add a theater (All fields)
    Given I am an Administrator
      And I am logged in
      And I go to the admin/theater page
      And I follow "New theater"
      And I fill in "Name" with "Theater Number One"
      And I select "Visiting Company" from "Theater class"
      And I select "Inactive" from "Status"
      And I press "Create"
     Then I should be on the admin/theater page
      And I should see "Theater Number One"

  Scenario: Add a theater (check valid values for select boxes)
    Given I am an Administrator
      And I am logged in
      And I go to the admin/theater page
      And I follow "New theater"
     Then I select "Default" from "Theater class"
      And I select "Resident Company" from "Theater class"
      And I select "Visiting Company" from "Theater class"
      And I select "Guest Artist" from "Theater class"
      And I select "Active" from "Status"
      And I select "Inactive" from "Status"

  Scenario: Add a theater (Name Required)
    Given I am an Administrator
      And I am logged in
      And I go to the admin/theater page
      And I follow "New theater"
      And I press "Create"
      And I should see "Name can't be blank"

  Scenario: Theater names must be unique
	Given I am an Administrator
      And the following theaters exist:
        | name        |
        | ABC Theater |
        | DEF Theater |
      And I am logged in
	  And I go to the admin/theater page
	  And I follow "New theater"
      And I fill in "Name" with "ABC Theater"
      And I press "Create"
     Then I should see "Name has already been taken"

  Scenario: Edit a theater
    Given I am an Administrator
      And the following theaters exist:
        | name        |
        | ABC Theater |
        | DEF Theater |
      And I am logged in
      And I go to the admin/theater page
      And I follow "ABC Theater" "Edit" link
     When I fill in "Name" with "ABD Theater"
      And I press "Save"
     Then I should be on the admin/theater page
      And I should see "ABD Theater"
      And I should see "Theater was successfully updated."

	Scenario: the logo is stored in a directory accessible by the web server
    Given I am an Administrator
      And I am logged in
      And I go to the admin/theater page
      And I follow "New theater"
      And I fill in "Name" with "Logo Theater"
      And I attach the test file "logo.jpg" to "theater_logo" 
      And I press "Create"
     Then I should see the logo for "Logo Theater"

