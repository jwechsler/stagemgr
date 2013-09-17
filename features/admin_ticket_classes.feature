Feature: An administrator can add theater classes to productions

  Background:
    Given a sample theater exists
    And I am an Administrator
    And I am logged in
    And I go to the admin production detail page for "Production One"

Scenario: There is a ticket classes link on the Productions Page
  Given I go to the admin production detail page for "Production One"
    And I follow "List"
   Then I should see "Listing ticket_classes"



