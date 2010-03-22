Feature: Admins can manage performances
  As an administrator
  I want to create / edit and delete performances records

  Background:
  Given the following productions exist:
    | name             |
    | Production One   |
    And the following ticket_classes exist on the Production "Production One":
    | class_code | class_name | ticket_price |
    | A          | A Ticket   | 10.00        |
    | B          | B Ticket   | 15.00        |
    | C          | C Ticket   | 20.00        |
    And I am an Administrator
    And I am logged in
    And I go to the admin production detail page for "Production One"

Scenario: There is a performances link on the Productions Page
  Given the following performances exist on the Production "Production One":
  | performance_code |
  | PERF             |
    And I go to the admin production detail page for "Production One"
   Then I should see "PERF"

Scenario: There is a New Performance link on the Performance Listing Page
  Given I go to the admin production detail page for "Production One"
   Then I should see "Add performance"

  Scenario: Add a performance (All fields)
  Given I follow "Add performance"
    And I select 01/01/2005 from "Performance date"
    And I select "Active" from "Status"
    And I fill in "Performance code" with "PERF1"
    And I fill in "performance_ticket_class_allocations_attributes_0_limit" with "10"
    And I check "performance_ticket_class_allocations_attributes_0_available"
   When I press "Create"
   Then I should see "Performance was successfully created."

@wip
Scenario: The box office user can see a listing of performances associated with a production
  Given I am a box office user
    And I am visiting the performance listing page
   Then I can see a list of performances defined that displays Date, Time, Status for each performance and displays the name of the associated production on the top of the page

@wip
Scenario: The box office user return to a production from the performance listing page
  Given I am a box office user
    And I am visiting the performance listing page
    And I click on the production name
   Then the user returns to the production detail page.

@wip
Scenario: The box office user can delete a performance
  Given I am a box office user
    And I am visiting the performance listing page
    And I click a delete button in the performance performance
   Then the system prompts me for confirmation. If confirmed, the performance is deleted, along with it's associated ticket class definitions.

@wip
Scenario: The box office user can duplicate a performance
  Given I am a box office user
    And I am visiting the performance listing page
    And I click a "duplicate" button in the performance row
   Then the system takes me to the New Performance Screen, with all the fields except date and time duplicated from the source record.  Date and Time should be blank.

@wip
Scenario: The box office user cannot create duplicate performances
  Given the user tries to save a production with the same date and time as another performance for the associated production.
   Then the system displays an alert dialog and will not save the record.


