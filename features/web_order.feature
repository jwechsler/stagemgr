Feature: Web ordering
  As an web site user
  I want to be able to buy tickets

  Background:
  Given the following productions exist:
    | name             | production_code |
    | Production One   | ABC12           |
    And the following ticket_classes exist on the Production "Production One":
    | class_code | class_name              | ticket_price | web_visible |
    | A          | Successful Transaction  | 1.00         | true        |
    | B          | Declined Transaction    | 2.00         | true        |
    | C          | C Ticket                | 20.00        | true        |
	And the following performances exist on the Production "Production One":
	| performance_code |
	| PERF             |
	And all the ticket class are available for Performance "PERF"
    And the following amount_off_special_offers exist:
    | amount | code           |
    | 1      | 1DollarOff     |
	
Scenario: Create an order
Given I go to new web order for production "ABC12" and performance "PERF"
And I fill in "First name" with "Tim"
And I fill in "Last name" with "Galeckas"
And I fill in "Email" with "tim@example.com"
And I fill in "Billing Address" with "123 Swift St"
And I fill in "City" with "Chicago"
And I fill in "State" with "IL"
And I fill in "Postal Code" with "60606"
And I select "1" from "order_ticket_line_items_attributes_0_ticket_count"
And I select "01" from "order_credit_card_expiration_month"
And I select "2018" from "order_credit_card_expiration_year"
And I select "Visa" from "Credit card type"
And I fill in "Credit card number" with "4111111111111111"
And I fill in "Credit card verification number" with "581"
And I press "Order tickets"
Then I should see "Order was successfully saved and is now"

Scenario: Create an order with a special offer
Given I go to new web order for production "ABC12" and performance "PERF"
And I fill in "First name" with "Tim"
And I fill in "Last name" with "Galeckas"
And I fill in "Email" with "tim@example.com"
And I fill in "Billing Address" with "123 Swift St"
And I fill in "City" with "Chicago"
And I fill in "State" with "IL"
And I fill in "Postal Code" with "60606"
And I select "1" from "order_ticket_line_items_attributes_2_ticket_count"
And I select "01" from "order_credit_card_expiration_month"
And I select "2018" from "order_credit_card_expiration_year"
And I select "Discover" from "Credit card type"
And I fill in "Credit card number" with "6011000990139424"
And I fill in "Credit card verification number" with "581"
And I fill in "Special offer code" with "1DollarOff"
And I press "Order tickets"
Then I should see "Order was successfully saved and is now"

Scenario: Have the credit card declined and then try again successfully
Given I go to new web order for production "ABC12" and performance "PERF"
And I fill in "First name" with "Tim"
And I fill in "Last name" with "Galeckas"
And I fill in "Email" with "tim@example.com"
And I fill in "Billing Address" with "123 Swift St"
And I fill in "City" with "Chicago"
And I fill in "State" with "IL"
And I fill in "Postal Code" with "60606"
And I select "1" from "order_ticket_line_items_attributes_1_ticket_count"
And I select "01" from "order_credit_card_expiration_month"
And I select "2018" from "order_credit_card_expiration_year"
And I select "Visa" from "Credit card type"
And I fill in "Credit card number" with "4222222222222"
And I fill in "Credit card verification number" with "581"
And I press "Order tickets"
And I should see "This transaction has been declined"
And I select "0" from "order_ticket_line_items_attributes_1_ticket_count"
And I select "1" from "order_ticket_line_items_attributes_0_ticket_count"
And I fill in "Credit card number" with "4111111111111111"
And I press "Order tickets"
Then I should see "Order was successfully saved and is now"

