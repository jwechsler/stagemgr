def enter_patron_information
  fill_in "Name", :with => "Jeremy Wechsler"
  fill_in "Email", :with => "test@theaterwit.org"
  fill_in "Billing Address", :with => "1229 W Belmont"
  fill_in "City", :with => "Chicago"
  fill_in "State", :with => "IL"
  fill_in "Zip", :with => "60657"
  fill_in "Phone", :with=>"555-555-1212"
end

Given /^I create a ticket order$/ do
  fill_in "ticket_order_production_code", :with => "ABC12"
  fill_in "ticket_order_performance_code", :with => "PERF"
  fill_in "ticket_order_ticket_line_items_attributes_0_ticket_class_code", :with => "A"
  fill_in "ticket_order_ticket_line_items_attributes_0_ticket_count", :with => "2"
  enter_patron_information
  select "Cash", :from => "ticket_order_payment_type"
  click_button "Place Order"
end

When /^I enter my contact information$/ do
  enter_patron_information
end

When /^I enter a valid credit card as payment$/ do
  select "Credit Card", :from=>"Pay using"
  choose "Visa"
  select "01", :from=>"ticket_order_credit_card_expiration_month"
  select "2018", :from=>"ticket_order_credit_card_expiration_year"
  fill_in "Credit card number", :with=>$TEST_CREDIT_CARD
  fill_in "CVV", :with=>"581"
  select Date.today.month.to_s, :from=>"Month"
  select Date.today.year.to_s, :from=>"Year"
end