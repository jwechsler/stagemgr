Feature: An administrator can add theater classes to productions

  Background:
    Given a sample theater exists
    And I am an Administrator
    And I am logged in

  @javascript @wip
  Scenario: There is a ticket classes link on the Theater Productions Page
    Given I go to the admin detail page for theater "Test Theater"
      And I follow "Ticket Classes"
     Then I should see "Ticket Classes"
      And I should see "New Ticket Class"
