Feature: User Administration
  In order to manage users on the back end
  As an administrator
  I want to control access to the application
  Background:
    Given a sample theater exists
    And I am an Administrator
    And I am logged in

  Scenario: Admins can make a user inactive
    Given: I am an administrator
       And a theater user "test@test.com" exists
       And I go to the admin edit page for user "test@test.com"
       And I set the status to "Inactive"
       And I press "Update"
       And I follow "Logout"
      Then I should see "Password"
       And I should see "Email"
      Then I sign in as user "test@test.com" with password "password"
       And I should see "test@test.com is currently inactive"
