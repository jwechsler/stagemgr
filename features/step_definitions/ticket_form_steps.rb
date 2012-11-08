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