Feature: Administer donation orders
  In order manage donations
  As an administrator
  I want to accept and return donations
  Background:
	Given the system accepts currency
    And a donation of "$10.00" exists
	  And I am an Administrator
	  And I am logged in

Scenario: The administrator can refund an order
  When I go to the admin order page for the donation
   And I follow "Refund Donation"
   And I press "Process Refund"
  Then I should see "-$10.00"
   And I should see "successfully refunded"






