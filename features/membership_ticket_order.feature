Feature: Membership ticket ordering
  As a member
  I want to reserve tickets with my membership and add a donation

  Background:
    Given a sample theater exists
      And a membership exists with member code "TESTMEM"

  Scenario: Reserve tickets with a membership and add a donation
    Given I go to new web order for production "Production One" and performance "TEST01"
      And I enter my contact information
      And I select "2" from "ticket_order_ticket_line_items_attributes_0_ticket_count"
      And I enter member code "TESTMEM" as payment
      And I enter a valid credit card as payment
      And I enter "15" as an additional donation
      And I press "Review Order"
     Then I should see "Your membership covers the tickets; $15.00 will be charged to your card ending 1111."
      And I press "Order Tickets"
     Then I should see "Your ticket reservation has been made"
      And I should not see "could not be processed"
      And a donation order for "15.00" exists
      And membership "TESTMEM" has been used for 2 tickets

  Scenario: A membership with a donation needs a card
    Given I go to new web order for production "Production One" and performance "TEST01"
      And I enter my contact information
      And I select "2" from "ticket_order_ticket_line_items_attributes_0_ticket_count"
      And I enter member code "TESTMEM" as payment
      And I enter "15" as an additional donation
      And I press "Review Order"
     Then I should see "Please enter a card for your donation."
      And membership "TESTMEM" has not been used

  @javascript
  Scenario: The card fields appear for a donation on a membership order
    Given I go to new web order for production "Production One" and performance "TEST01"
      And I choose "Membership"
     Then the card fields should be hidden
     When I enter "15" as an additional donation
     Then the card fields should be visible
      And I should see "Your membership covers the tickets. Your $15.00 donation will be charged to this card:"
     When I enter "" as an additional donation
     Then the card fields should be hidden
     When I choose "Credit Card"
     Then the card fields should be visible
      And I should not see "covers the tickets"
