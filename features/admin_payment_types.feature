Feature: Payment Types Administration
  As an administrator
  I want to create / edit and delete payment types
  Background:
    Given a sample theater exists
    And I am an Administrator
    And I am logged in


  Scenario: Payment Types exists under the System Options page
    Given I go to the system options page
    Then I should see "Manage Payment Types"


  Scenario: Existing payment types are displayed to the administrator
    Given I go to the manage payment types page
     Then I should see "Credit Card"
      And I should see "Cash"
      And I should see "Membership"
      And I should see "Flex Pass"
      And I should see "Edit"

  @javascript @wip
  Scenario: Make a payment type active for the public
    Given I go to the edit page for payment type "Cash"
      And I allow cash payments for the public
      And I press "Update"
     Then I should see "successfully updated"
      And I visit the new admin ticket order page
      And the payment option should include "Cash"
      And I log out
      And I go to new web order for production "Production One" and performance "TEST01"
      And show me the page
      And the payment option should include "Cash"
      And I log in
      And I go to the edit page for payment type "Cash"
      And I disallow cash payments for the public
      And I press "Update"
      And I visit the new admin ticket order page
      And show me the page
      And the payment option should include "Cash"
      And I log out
      And I go to new web order for production "Production One" and performance "TEST01"
      And show me the page
      And the payment option should not include "Cash"

  Scenario: Payment Types can be marked as not reportable as sales
     Given I go to the edit page for payment type "Cash"
       And I should see "Report as sales collected"
       And I disallow reporting sales
       And I press "Update"
      Then I should see "successfully updated"

#  @javascript @pending
#  Scenario: Set up suppression rules
#    Given I go to the edit page for payment type "Cash"
#      And I allow cash payments for the public
#      And I suppress the "ticket_confirmation" method for "OutreachTask"
#      And I press "Update"
#     Then I should see "successfully updated"
#      And I go to the edit page for payment type "Cash"
#     Then the suppression type should be 'OutreachTask'
#      And the suppression method should be 'ticket_confirmation'
#      And I follow "remove"
#      And I press "Update"
#     Then I should see "successfully updated"
#      And I go to the edit page for payment type "Cash"
#     Then I should not see "OutreachTask"
#      And I should not see "ticket_confirmation"
