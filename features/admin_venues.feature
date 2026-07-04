Feature: The Administrator can manage venue seat maps
  In order to see which seat maps exist for a venue
  As an admin or box office user
  I want to view the seat map listing for a venue without errors

  Background:
    Given a sample theater exists

  @javascript
  Scenario: Admin can view the seat-map-listing datatable for a venue without errors
    Given a venue "Main Stage" exists
      And I am an Administrator
      And I am logged in
      And I go to the admin venue page for "Main Stage"
     Then I wait for the datatable to load
      And I should see "Tiny House"

  @javascript
  Scenario: Box office user can view the seat-map-listing datatable for a venue
    Given a venue "Main Stage" exists
      And I am a Box Office user
      And I am logged in
      And I go to the admin venue page for "Main Stage"
     Then I wait for the datatable to load
      And I should see "Tiny House"

  @javascript
  Scenario: Admin can open the graphical seat map editor
    Given a venue "Main Stage" exists
      And I am an Administrator
      And I am logged in
      And I go to the seat map editor for venue "Main Stage"
     Then I should see "Add Seat"
      And I should see "Save"
