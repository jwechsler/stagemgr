@wip
Feature: Flex Pass Ticket Order administration
  In order to handle flex pass orders from the backend
  As a box office user and administrator
  I want to manage tickets paid for with flex passes

  Background:
    Given a sample theater exists
      And a flex pass exists for 2 tickets with code "TESTFLEX"

  Scenario: Box office users cannot refund a ticket order paid with a flex pass
    Given a ticket order for performance "PERF" paid with flex pass "TESTFLEX" exists
      And I am a box office user
      And I am logged in
      And I go to the admin order page for the ticket order
      And I should not see "Refund Order"

  Scenario: Admins can refund a ticket order paid with a flex pass
    Given a ticket order for performance "PERF" paid with flex pass "TESTFLEX" exists
      And I am an administrator
      And I am logged in
      And I go to the admin order page for the ticket order
      And I follow "Refund Order"
      And show me the page
      And I press "Release Flex Pass tickets"
     Then I should see "Order was successfully refunded"

