Feature: Flex Pass Ticket Order administration
  In order to handle flex pass orders from the backend
  As a box office user and administrator
  I want to manage tickets paid for with flex passes

  Background:
    Given a sample theater exists
      And a flex pass exists for 2 tickets with code "TESTFLEX"

  Scenario: Box Office can refund a ticket order paid with a flex pass
    Given a ticket order for performance "PERF" paid with flex pass "TESTFLEX" exists
      And I am a box office user
      And I am logged in
      And I go to the admin order page for the ticket order
      And I follow "Refund Order"
      And I press "Release Flex Pass tickets"
     Then I should see "Order was successfully refunded"

  Scenario: Box office users can exchange a flex pass order
     Given a ticket order for performance "PERF" paid with flex pass "TESTFLEX" exists
       And a performance "NEWPERF" exists
       And the performance "NEWPERF" has a ticket class code "PASS"
       And I am a box office user
       And I am logged in
       And I go to the admin order page for the ticket order
       And I follow "Exchange Order"
       And I enter an exchange for the order to performance "NEWPERF"
       And I enter 2 tickets for performance "NEWPERF"
       And I enter flex pass code "TESTFLEX" as payment
       And I press "Place Order"
      Then I should see "Order was successfully exchanged"