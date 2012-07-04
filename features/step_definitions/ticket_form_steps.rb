Given /^I create a ticket order$/ do
  fill_in "ticket_order_production_code", :with=>"ABC12"
  fill_in "ticket_order_performance_code", :with=>"PERF"
  fill_in "ticket_order_ticket_line_items_attributes_0_ticket_class_code", :with=>"A"
  fill_in "ticket_order_ticket_line_items_attributes_0_ticket_count", :with=>"2"
  fill_in "Full name", :with=>"TEST BUYER"
  fill_in "ticket_order_address_attributes_line1", :with=> "123 main st"
  fill_in "ticket_order_address_attributes_line2", :with=> "Apt. 2A"
  fill_in "City", :with=>"Chicago"
  fill_in "State", :with=> "IL"
  fill_in "ticket_order_address_attributes_zipcode", :with=>"60657"
  select  "Cash", :from=>"ticket_order_payment_type"
  click_button "Place Order"
end
