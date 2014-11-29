Feature: Box office users can manage special feature options
  As a box office user
  I want to create / edit and delete standard special feature requests

  Background:
    Given a sample theater exists
    And I am a box office user
    And I am logged in

  Scenario: Create a special feature
    Given I go to the new special feature page
      And I enter a special feature called "Test" with a description of "Test Feature\n\nHello there!"
      And I press "Create Special feature"
      Then I should see "Successfully created special feature"
