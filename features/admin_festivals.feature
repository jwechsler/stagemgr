Feature: Administer Festivals
  In order to group productions under a shared festival brand
  As a box office user or administrator
  I want to create, edit, and assign festivals

  Background:
    Given a sample theater exists

  Scenario: There is a 'Festivals' menu link for box office users
    Given I am a box office user
      And I am logged in
      And I go to the home page
     Then "Festivals" should link to "the admin festivals page"

  Scenario: There is not a 'Festivals' menu link for theater users
    Given I am a theater user
      And I am logged in
      And I go to the home page
     Then I should not see "Festivals"

  Scenario: Box office users can create a festival
    Given I am a box office user
      And I am logged in
      And I go to the admin festivals page
      And I follow "New Festival"
      And I fill in "Name" with "Physical Theatre Festival"
      And I press "Create Festival"
     Then I should see "Festival was successfully created"
      And I should see "Physical Theatre Festival"

  Scenario: Box office users can assign a production to a festival
    Given a festival "Physical Theatre Festival" exists
      And I am a box office user
      And I am logged in
      And I go to the admin production edit page for "Production One"
      And I select "Physical Theatre Festival" from "Festival"
      And I press "Update Production"
     Then the production "TEST" should belong to the festival "Physical Theatre Festival"

  Scenario: Theater users cannot create festivals
    Given I am a theater user
      And I am logged in
      And I go to the new admin festival page
     Then I should see "You are not authorized to access this page"

  @javascript
  Scenario: Destroying a festival with assigned productions is blocked
    Given a festival "Physical Theatre Festival" exists
      And the production "TEST" belongs to the festival "Physical Theatre Festival"
      And I am an Administrator
      And I am logged in
      And I go to the admin festivals page
      And I follow "Destroy"
     Then I should see "This festival still has productions assigned"
      And a festival "Physical Theatre Festival" should still exist
