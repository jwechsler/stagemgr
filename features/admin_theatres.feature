Feature: The Administrator can manage theater records
  In order to create theaters to attach performances and ticket classes to
  As a StageMgr Admin user
  I want to create / edit and delete theater records

  Background:
    Given a sample theater exists

  Scenario: There is a 'Theaters' menu link for admins
    Given I am an Administrator
      And I am logged in
      And I go to the home page
     Then "Theaters" should link to "the admin theater page"


  Scenario: There is not a 'Theaters' menu link for non-admins
  	Given I am a theater user
      And I am logged in
      And I go to the home page
     Then I should see "Your Theaters"

  @javascript
  Scenario: List theaters as admin
    Given a theater "ABC Theater" exists
      And a theater "DEF Theater" exists
	    And I am an Administrator
      And I am logged in
      And I go to the home page
      And I go to the admin theater page
     Then I should see "ABC Theater"
      And I should see "DEF Theater"
      And each theater name is a link to a theater detail page

  @javascript
  Scenario: Add a theater
    Given I am an Administrator
      And I am logged in
      And I go to the admin/theater page
      And I follow "New theater"
      And I enter a theater called "Theater Number One"
      And I press "Create"
     Then I should be on the admin/theater page
      And I should see "Theater Number One"

  @javascript
  Scenario: Edit a theater
    Given I am an Administrator
      And a theater "ABC Theater" exists
      And I am logged in
      And I go to the admin/theater page
      And I follow "edit_abc_theater"
     When I change "Name" to "ABD Theater"
      And I press "Update"
     Then I should be on the admin/theater page
      And I should see "ABD Theater"
      And I should see "Theater was successfully updated."
