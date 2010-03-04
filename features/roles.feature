Feature: There needs to be roles
  In order to
  Users should be able to have one or more of three roles:
  Administrator, Box office user, and Theater Owner

  Background:
	Given the following users exist:
    | email           | 
    | one@example.com |    
    | two@example.com |    
    And I am an Administrator
    And I am logged in

  Scenario: Make a user an administrator
  Given I make 'one@example.com' an administrator
   Then I should see that 'one@example.com' is an administrator

  Scenario: Make a user an box office user
  Given I make 'one@example.com' a box office user
   Then I should see that 'one@example.com' is a box office user

  Scenario: Make a user a theater owner
  Given I make 'one@example.com' a theater owner
   Then I should see that 'one@example.com' is a theater owner

  Scenario: Administrators and box office users should be able to see all theaters
  Scenario: Theater owners should see their theaters
  Scenario: Administrators should be the only one able to make other users
  Scenario: Box office users should be able to sell tickets

