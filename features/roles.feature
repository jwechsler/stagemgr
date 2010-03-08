Feature: Certain roles have certain responsibilities
  In order to protect data and transactions
  As a user
  I need to be granted access to functions that are necessary for my role and
  denied access for functions that are not necessary for my role

  Background:
	Given the following users exist:
    | email           | 
    | one@example.com |    
    | two@example.com |    
    And I am an Administrator
    And I am logged in
    
  Scenario: Every Role Role
    Given there exists a user
      And that user has the "Every Role" role
     When I log into the site as that user
     Then I should be able to take in person ticket orders
      And I should be able to take phone ticket orders
      And I should be able to give refunds for ticket orders
      And I should be able to edit/list/show theaters
      And I should be able to make comp reservations
      And I should be able to edit/list/show productions
      And I should be able to edit/list/show users
      And I should be able to edit/list/show roles
      And I should be able to edit/list/show performances
      And I should be able to edit/list/show ticket classes
      And I should be able to edit/list/show reports
      And I should be able to edit/list/show flex passes
      And I should be able to list/show/edit orders and fulfillments
      And I should be able to run reports
      And I should be able to cancel held orders
      And I should be able to refund processed orders
      
  Scenario: Box Office Administrator Role
    Given there exists a user
      And that user has the "Box Office Administrator" role
      When I log into the site as that user
      Then I should be able to take in person ticket orders
       And I should be able to take phone ticket orders
       And I should be able to give refunds for ticket orders
       And I should be able to edit/list/show theaters
       And I should be able to make comp reservations
       And I should be able to edit/list/show productions
       And I should not be able to edit/list/show users
       And I should not be able to edit/list/show roles
       And I should be able to edit/list/show performances
       And I should be able to edit/list/show ticket classes
       And I should be able to edit/list/show reports
       And I should be able to edit/list/show flex passes
       And I should be able to list/show/edit orders and fulfillments
       And I should be able to cancel held orders
       And I should be able to refund processed orders
       And I should be able to run reports


  Scenario: Box Office Attendant Role
    Given there exists a user
      And that user has the "Box Office Attendant" role
     When I log into the site as that user
     Then I should be able to take in person ticket orders
      And I should be able to take phone ticket orders
      And I should be able to give refunds for ticket orders
      And I should be able to edit/list/show theaters
      And I should not be able to make comp reservations
      And I should be able to list/show productions
      And I should not be able to edit productions
      And I should not be able to edit/list/show users
      And I should not be able to edit/list/show roles
      And I should be able to list/show performances
      And I should not be able to edit performances
      And I should be able to list/show ticket classes
      And I should not be able to edit ticket classes
      And I should be able to list/show reports
      And I should not be able to edit reports
      And I should be able to list/show flex passes
      And I should not be able to edit flex passes
      And I should be able to list/show/edit orders and fulfillments
      And I should be able to cancel held orders
      And I should not be able to refund processed orders
      And I should be able to run reports
            
  Scenario: Theater User Role
    Given there exists a user
      And that user has the "Theater User" role (for a Theater record)
     When I log into the site as that user
     Then I should not be able to take in person ticket orders
      And I should not be able to take phone ticket orders
      And I should not be able to give refunds for ticket orders
      And I should be able to make comp reservations
      And I should be able to edit/list/show productions
      And I should not be able to manage users
      And I should not be able to manage roles
      And I should be able to manage performances owned by my theater
      And I should be able to list/show performances owned by my theater
      And I should be able to list/show ticket classes owned by my theater
      And I should not be able to edit performances
      And I should not be able to edit ticket classes
      And I should be able to run reports for my theater
      And I should not be able to edit/list/show flex passes
      And I should not be able to list/show/edit orders and fulfillments
      And I should not be able to cancel held orders
      And I should not be able to refund processed orders


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
