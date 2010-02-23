Feature: The Administrator can manage theater records
  In order to create theaters to attach performances and ticket classes to
  As a StageMgr Admin user
  I want to create / edit and delete theater records

  Scenario: There is a 'Theaters' menu link for admins
    Given I am an 'Administrator'
      And I am logged in
     When I go to the home page
     Then I should see a link labeled 'Theaters'

  Scenario: There is not a 'Theaters' menu link for non-admins
  	Given I am not an 'Administrator'
      And I am logged in
     When I go to the home page
     Then I should not see a link labeled 'Theaters'

  Scenario: List theaters as admin
    Given I am an 'Administrator'
    And the following theaters exist:
        | name        |
        | ABC Theater |
        | DEF Theater |
    And I am logged in
    When I go to the admin/theater page
    Then I should see 'ABC Theater'
     And I should see 'DEF Theater'
     And each name is a link to a page to edit the theater record
  
	@wip
  Scenario: Add a theater
    Given I have the role 'Administrator'
    When I visit the admin/theaters page
      And I click on a Add new theater button
    Then the system allows the user to enter Name | URL | Logo (uploaded image) | Class (Default / Resident / Renter) | Status ( Active / Inactive )
      And click "Save"
    Then the user is returned to the theaters list, and the new theater is visibile
      And the logo is stored in a directory accessible by the web server
      And the name of the theater is unique

	@wip
  Scenario: Edit a theater
    Given I have the role 'Administrator'
      And there is more than one theater in the system
    When I visit the admin/theaters page
      And I click on the name of a theater
