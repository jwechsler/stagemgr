
Feature: The Administrator can manage theater records
  In order to create theaters to attach performances and ticket classes to
  As a StageMgr Admin user
  I want to create / edit and delete theater records

	Scenario: the logo is stored in a directory accessible by the web server
    Given I am an Administrator
      And I am logged in
      And I go to the admin/theater page
      And I follow "New theater"
      And I fill in "Name" with "Logo Theater"
      And I attach the test file "logo.jpg" to "theater_logo"
      And I press "Create"
     Then I should see the logo for "Logo Theater"

