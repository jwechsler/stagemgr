Feature: Admins can manage performances
  As an administrator
  I want to create / edit and delete performances records

  Background:
  Given the following productions exist:
    | name             |
    | Production One   |
    And I am an Administrator
    And I am logged in
    And I go to the admin production detail page for "Production One"

Scenario: There is a performances link on the Productions Page
  Given the following performances exist on the Production "Production One":
   Then there is a link to the performance listing page.

