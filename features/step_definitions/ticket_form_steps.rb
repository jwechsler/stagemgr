def enter_patron_information
  fill_in "Name", :with => "Ticket Buyer"
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

Given /^I enter a gift recipient$/ do
  fill_in "Recipient name", :with=>"Gift Getter"
  fill_in "Recipient email", :with=>"test@theaterwit.org"
end

When /^I prefer "(.*?)" seating$/ do |seating_preference|
  select seating_preference, :from=>"Preferred Seating"
end


When /^I enter a valid credit card as payment( through the backend)?$/ do |backend|
  @_current_form = 'ticket_order' if @_current_form.blank?
  select "Credit Card", :from=>"Pay using"
  choose "Visa"
  unless @using_admin_interface
    select "01", :from=>"#{@_current_form}_credit_card_expiration_month"
  else
    fill_in "MM", :with=>Date.today.month.to_s
  end
  unless @using_admin_interface
    select "2018", :from=>"#{@_current_form}_credit_card_expiration_year"
  else
    fill_in "YY", :with=>'18'
  end
  fill_in "Credit card number", :with=>"4111111111111111"
  fill_in "CVV", :with=>"581"
end

Given /^I enter flex pass (code )?"(.*?)" as payment$/ do |ignore, pass_code|
  @_current_form = 'ticket_order' if @_current_form.blank?
  select "Flex Pass", :from=>"Pay using"
  fill_in "Flex pass code", :with=>"#{pass_code}"
end

Given /^I enter (\d+) tickets for performance "(.*?)"$/ do |num_tix, perf_code|
  performance = Performance.find_by_performance_code(perf_code)
  ticket_class_code = performance.ticket_class_allocations.select{|tca| tca.ticket_class.web_visible}.first.ticket_class.class_code
  fill_in "ticket_order_ticket_line_items_attributes_0_ticket_class_code", :with =>  ticket_class_code
  fill_in "ticket_order_ticket_line_items_attributes_0_ticket_count", :with => num_tix
end

Given /^I enter an exchange for the order to performance "(.*?)"$/ do |perf_code|
  fill_in "ticket_order_production_code", :with => Performance.find_by_performance_code(perf_code).production.production_code
  fill_in "ticket_order_performance_code", :with => perf_code
end


