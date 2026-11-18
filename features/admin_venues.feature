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

  @javascript
  Scenario: Admin changes a seat's row and number in the graphical editor
    Given a venue "Main Stage" exists
      And the seat map for venue "Main Stage" is plotted
      And I am an Administrator
      And I am logged in
      And I go to the seat map editor for venue "Main Stage"
      And the seat map editor has loaded 8 seats
     When I click the first seat in the seat map editor
      And I enter "QQ" in the editor's Row box
      And I enter "42" in the editor's Number box
     Then the editor should show unsaved changes
     When I save the seat map editor
     Then the clicked seat should have row "QQ" and number 42 with its location unchanged

  @javascript
  Scenario: The graphical editor rejects a seat number below 1
    Given a venue "Main Stage" exists
      And the seat map for venue "Main Stage" is plotted
      And I am an Administrator
      And I am logged in
      And I go to the seat map editor for venue "Main Stage"
      And the seat map editor has loaded 8 seats
     When I click the first seat in the seat map editor
      And I enter "0" in the editor's Number box
     Then the editor status should be the error "Seat number must be a whole number of 1 or more"
      And the editor should not show unsaved changes
