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
@wip
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
    And I fill in "performance_ticket_class_allocations_attributes_0_ticket_limit" with "10"
    And I check "performance_ticket_class_allocations_attributes_0_available"
   When I press "Create"
   Then I should see "Performance was successfully created."

Scenario: There cannot be more than one performance at the same time
Given I follow "Add performance"
  And I select 01/01/2005 from "Performance date"
  And I select "Active" from "Status"
  And I fill in "Performance code" with "PERF1"
  And I fill in "performance_ticket_class_allocations_attributes_0_ticket_limit" with "10"
  And I check "performance_ticket_class_allocations_attributes_0_available"
  And I press "Create"
  And I should see "Performance was successfully created."
  And I go to the admin production detail page for "Production One"
  And I follow "Add performance"
  And I select 01/01/2005 from "Performance date"
  And I select "Active" from "Status"
  And I fill in "Performance code" with "PERF2"
  And I fill in "performance_ticket_class_allocations_attributes_0_ticket_limit" with "10"
  And I check "performance_ticket_class_allocations_attributes_0_available"
 When I press "Create"
  And I should see "Performance time has already been taken"

Scenario: The box office user can duplicate a performance
Given I follow "Add performance"
  And I select 01/01/2005 from "Performance date"
  And I select "Active" from "Status"
  And I fill in "Performance code" with "PERF1"
  And I fill in "performance_ticket_class_allocations_attributes_0_ticket_limit" with "10"
  And I check "performance_ticket_class_allocations_attributes_0_available"
  And I press "Create"
  And I should see "Performance was successfully created."
  And I go to the admin production detail page for "Production One"
  And I follow "Duplicate"
  And I fill in "Performance code" with "PERF2"
 When I press "Create"
  And I should see "Performance time has already been taken"
