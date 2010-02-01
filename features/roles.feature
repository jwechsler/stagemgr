Feature: Certain roles have certian responsibilities
  In order to protect data and transactions
  As a user
  I need to be granted access to functions that are necessary for my role and
  denied access for functions that are not necessary for my role

  Scenario: Every Role Role
    Given there exists a user
      And that user has every role
     When I log into the site as that user
     Then I should be able to take in person ticket orders
      And I should be able to take phone ticket orders
      And I should be able to give refunds for ticket orders
      And I should be able to edit/list/show users
      And I should be able to edit/list/show roles
      And I should be able to edit/list/show performances
      And I should be able to edit/list/show ticket classes
      And I should be able to edit/list/show reports

  Scenario: Box Office Attendant Role
    Given there exists a user
      And that user has the "Box Office Attendant" role
     When I log into the site as that user
     Then I should be able to take in person ticket orders
      And I should be able to take phone ticket orders
      And I should be able to give refunds for ticket orders
      And I should not be able to edit/list/show users
      And I should not be able to edit roles
      And I should be able to list/show roles
        And I should not be able to edit performances
      And I should not be able to edit/list/show reports

  Scenario: Stagemgr Administrator Role
    Given there exists a user
      And that user has the "Stagemgr Administrator" role
     When I log into the site as that user
     Then I should not be able to take in person ticket orders
      And I should not be able to take phone ticket orders
      And I should not be able to give refunds for ticket orders
      And I should be able to manage users
      And I should be able to manage roles
      And I should be able to manage performances
      And I should be able to manage reports
      And I should be able to run reports

