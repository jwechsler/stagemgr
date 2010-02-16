Feature: An administrator can add production details to a theater
  Given a theater has been created
  As a StageMgr Admin user
  I want to create / edit and delete production records

  Background:
    Given the following theaters exist:
    | name          |
    | Theater One   |
    And I am a StageMgr Admin
    And I log in to the site

  Scenario: Add a production
    Given the user has the create production permission
    When the administrator visits the theater detail page
      And clicks "Add production"
    Then the administrator can create a production record associated to the theater
      Name | Credit Lines (text) | First Preview (date) | Press Opening (date) | Opening (date) | Closing (date) | Show description (html) | Capacity | Additional Information (link) | Status (Active/Inactive)
  
  Scenario: Delete a production
    Given the user is associated to at least one theater
      And has the delete production privilege
      And the user visits the theater detail page
    When the user sees a delete link next to each production
      And the user clicks on that link
      And the user confirms the delete
      And the production has no associated peformances
    Then the production is deleted.

  Scenario: Edit a production
    Given the user has the edit production privilege
    When the adminstrator visits the theater detail page
      And clicks on a production link
    Then the system allows the user to edit
      Name | Credit Lines (text) | First Preview (date) | Press Opening (date) | Opening (date) | Closing (date) | Show description (html) | Capacity | Additional Information (link) | Status (Active/Inactive)
    
  Scenario: View a production
    Given the user is associated with a theater
    When the user visits the theater detail page
      And clicks on a theater name
    Then the production detail screen is presented
      Showing all defined field values for that production

