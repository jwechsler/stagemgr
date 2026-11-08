Feature: Box office exchanges and refunds of ticket orders
  In order to change or return a patron's tickets
  As a box office user
  I want exchanges and refunds to settle every payment

  Background:
    Given a sample theater exists
      And a performance "TEST02" exists
      And all the ticket class are available for Performance "TEST02"
      And I am a box office user
      And I am logged in

  Scenario: Exchanging a card order into pricier tickets charges the difference to a card
    Given a ticket order for 2 "CHEAP" tickets to performance "TEST01" paid with credit card exists
      And I go to the admin order page for the ticket order
      And I follow "Exchange Order"
      And I exchange for 2 "RICH" tickets to performance "TEST02"
      And I enter a valid credit card as payment through the backend
      And I press "Exchange Order"
     Then I should see "Order was successfully exchanged"
      And the original order should be "Exchanged" with payments netting to zero
      And the exchange order should be "Processed" with payments totalling "$20.00"
      And the exchange order should have 1 "CreditCardPayment" of "$10.00"

  Scenario: Exchange and Refund into cheaper tickets refunds the difference to the card
    Given a ticket order for 2 "RICH" tickets to performance "TEST01" paid with credit card exists
      And I go to the admin order page for the ticket order
      And I follow "Exchange Order"
      And I exchange for 2 "CHEAP" tickets to performance "TEST01"
      And I press "Exchange and Refund"
     Then I should see "Order was successfully exchanged"
      And the original order should be "Exchanged" with payments netting to zero
      And the original order should have 1 "RefundPayment" of "-$10.00"
      And the gateway should have refunded "$10.00" of the original card charge
      And the exchange order should be "Processed" with payments totalling "$10.00"

  Scenario: A plain exchange into cheaper tickets writes the difference off as a carryover
    Given a ticket order for 2 "RICH" tickets to performance "TEST01" paid with credit card exists
      And I go to the admin order page for the ticket order
      And I follow "Exchange Order"
      And I exchange for 2 "CHEAP" tickets to performance "TEST01"
      And I press "Exchange Order"
     Then I should see "Order was successfully exchanged"
      And the original order should be "Exchanged" with payments netting to zero
      And the original order should have 0 "RefundPayment" of "-$10.00"
      And the exchange order should have 1 "PriceOverridePayment" of "-$10.00"
      And the exchange order should be "Processed" with payments totalling "$10.00"

  Scenario: Refunding a cash-paid ticket order records one refund and releases the tickets
    Given a ticket order for 2 "RICH" tickets to performance "TEST01" paid with cash exists
      And I go to the admin order page for the ticket order
      And I follow "Refund Order"
      And I press "Process Refund"
     Then I should see "Order was successfully refunded"
      And the ticket order should be "Refunded" with exactly one refund payment of "-$20.00"
      And the ticket order's tickets should be released

  Scenario: Refunding a card-paid ticket order refunds the charge through the gateway
    Given a ticket order for 2 "RICH" tickets to performance "TEST01" paid with credit card exists
      And I go to the admin order page for the ticket order
      And I follow "Refund Order"
      And I press "Process Refund"
     Then I should see "Order was successfully refunded"
      And the ticket order should be "Refunded" with exactly one refund payment of "-$20.00"
      And the gateway should have refunded "$20.00" of the original card charge
      And the ticket order's tickets should be released
