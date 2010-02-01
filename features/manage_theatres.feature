Feature: The Administrator can manage theater records
  In order to create theaters to attach performances and ticket classes to
  As the StageMgr Admin user
  I want to create / edit and delete theater records

  Scenario: List theaters as admin
    Given the user is an administrator
    And there is at least one defined theater in the system
    When the administrator visits the admin/theater page
    Then the user sees a list of theater names, ordered alphabetically
     And each name is a link to a page to edit the theater record
  
  Scenario: Add a theater
    Given the user is an administrator
    When the adminstrator visits the admin/theaters page
      And clicks on a Add new theater button
    Then the system allows the user to enter
      Name | URL | Logo (uploaded image) | Class (Default / Resident / Renter) | Status ( Active / Inactive )
      And click "Save
    Then the user is returned to the theaters list, and the new theater is visibile
      And the logo is stored in a directory accessible by the web server
      And the name of the theater is unique

  Scenario: Edit a theater
    Given the user is an administrator
      And there is more than one theater in the system
    When the administrator visits the admin/theaters page
      And clicks on the name of a theater