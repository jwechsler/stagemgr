Feature: Admins can manage performances
  As an administrator
  I want to create / edit and delete performances records

  Background:
    Given the following theaters exist:
    | name          |
    | Theater One   |
    And the following productions exist:
    | name             |
    | Production One   |
    And I am an Administrator
    And I am logged in
    And I go to the home page
    And I follow "Theaters"
    And I follow "Theater One"

Scenario: There is a performances link on the Productions Page
  Given I am visit the production detail page
    And there is at least one performance defined for the production
   Then there is a link to the performance listing page.

