def enter_patron_information
  fill_in "Name", :with => "Ticket Buyer"
  fill_in "Email", :with => "test@theaterwit.org"
  fill_in "Street", :with => "1229 W Belmont"
  fill_in "City", :with => "Chicago"
  fill_in "State", :with => "IL"
  fill_in "Zip", :with => "60657"
  fill_in "Phone", :with=>"555-555-1212"
end

When /^I place the order$/ do
  click_button('Place Order')
  page.driver.browser.switch_to.alert.accept
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

When /^I enter my contact information incorrectly$/ do
  enter_patron_information
  fill_in "Email", :with=>''
  fill_in "Street Address", :with=>''
end

Given /^I enter a gift recipient$/ do
  fill_in "Recipient name", :with=>"Gift Getter"
  fill_in "Recipient email", :with=>"test@theaterwit.org"
  fill_in :membership_order_gift_date, :with=>Date.today
end

When /^I prefer "(.*?)" seating$/ do |seating_preference|
  select seating_preference, :from=>"Preferred Seating"
end

When /^I enter a valid credit card as payment through the backend?$/ do
  @_current_form = 'ticket_order' if @_current_form.blank?

  select "Credit Card", from: "#{@_current_form}_payment_type_id"
  select 'bogus', from:"#{@_current_form}_credit_card_type"
  # select "Visa", :from=>"#{@_current_form}_credit_card_type"
  fill_in "#{@_current_form}_credit_card_expiration_month", :with=>"01"
  fill_in "#{@_current_form}_credit_card_expiration_year", :with=>'21'
  fill_in 'Credit card number', :with=>"4111111111111111"
  fill_in "CVV", :with=>"581"
end

Given("I enter a valid credit card as payment") do

  select 'Visa', from: "Card"
  # select "Visa", :from=>"#{@_current_form}_credit_card_type"
  select "01", from: "Month"
  select (Date.current.year+1).to_s, from: "Year"
  fill_in 'Card #', :with=>"4111111111111111"
  fill_in "CVV", :with=>"581"
end


Given /^I choose "(.*?)" as payment$/ do |external_payment|
  select external_payment, :from=>"Pay using"
end

Given /^I enter a check number "(.*?)" as payment$/ do |check_number|
  select "Check", :from=>"Pay using"
  fill_in "Check number", :with=>check_number
end

Given /^I enter flex pass( code)? "(.*?)" as payment$/ do |ignore, pass_code|
  @_current_form = 'ticket_order' if @_current_form.blank?
  if @using_admin_interface
    select "Flex Pass", :from=>'Pay using'
  else
    choose "Flex Pass"
  end
  fill_in "Flex pass code", :with=>"#{pass_code}"
end

Given /^I enter (\d+) tickets for performance "(.*?)"$/ do |num_tix, perf_code|
  performance = Performance.find_by_performance_code(perf_code)
  @performance_code = perf_code
  ticket_class = performance.ticket_class_allocations.select{|tca| tca.ticket_class.web_visible}.first.ticket_class
  fill_in "ticket_order_ticket_line_items_attributes_0_ticket_class_code", :with =>  ticket_class.class_code
  fill_in "ticket_order_ticket_line_items_attributes_0_ticket_count", :with => num_tix
end

Given /^I enter an exchange for the order to performance "(.*?)"$/ do |perf_code|
  fill_in "ticket_order_production_code", :with => Performance.find_by_performance_code(perf_code).production.production_code
  fill_in "ticket_order_performance_code", :with => perf_code
end

Then /^the payment option should include "(.*?)"$/ do |value|

  page.has_checked_field?('#ticket_order_payment_type_id',:with=>value)
  # "//select[@id = 'ticket_order_payment_type_id']/option[text() = '#{value}']"
end

Then /^the payment option should not include "(.*?)"$/ do |value|
  page.should_not have_xpath "//select[@id = 'ticket_order_payment_type_id']/option[text() = '#{value}']"
end

Given(/^I mark the order as held under "(.*?)"$/) do |hold_under_name|
  fill_in "ticket_order_hold_under", :with=> hold_under_name
end

