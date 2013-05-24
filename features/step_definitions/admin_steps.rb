def enter_base_production(code, capacity = 99)
  fill_in "Production code", :with=>code
  fill_in "Name", :with=>"Production #{code}"
  fill_in "Capacity", :with=>capacity
  fill_in "Season", :with=>Date.today.year
  select "Space 1", :from=>"Venue"
end

Given /^I enter a performance on "(.*?)" with code "(.*?)"$/ do |perf_date, perf_code|
  fill_in "performance_performance_date", :with=>perf_date
  select "Active", :from=>"Status"
  fill_in "Performance code", :with=>perf_code
end

Given /^I enter a performance date of "(.*?)"$/ do |perf_date|
  fill_in "Performance date", :with=>perf_date
end

Given /^I enter a production with code "(.*?)" and [|a ] capacity of "(.*?)"$/ do |code, capacity|
  enter_base_production(code, capacity)
end

Given /^I enter a complete production with code "(.*?)"$/ do |code|
  enter_base_production(code)
  fill_in "Credit lines", :with=>"by Willard Shakepare"
  fill_in "production_first_preview_at", :with=>"#{Date.today.year}-01-01"
  fill_in "production_press_opening_at", :with=>"#{Date.today.year}-01-01"
  fill_in "production_opening_at", :with=>"#{Date.today.year}-01-01"
  fill_in "production_closing_at", :with=>"#{Date.today.year}-01-01"
  fill_in "Show description", :with=>"<h1>Hello</h1>"
  fill_in "Capacity", :with=>"300"
  fill_in "Additional information link", :with=>"http://google.com"
  select "Active", :from=>"Status"
end

When /^all production status values are presented$/ do
  Production::PRODUCTION_STATUSES.each {|status| select status,:from=>"Status"}
end

When /^I enter a theater called "([^\"]*)"$/ do |name|
  fill_in "Name", :with=>name
  select Theater::THEATER_CLASSES.first, :from=>"Theater class"
end

When /^I enter production code "([^\"]*)" and performance code "([^\"]*)"$/ do |prod_code, perf_code|
  fill_in "ticket_order_production_code", :with=>prod_code
  fill_in "ticket_order_performance_code", :with=>perf_code
end

When /^I enter (\d+) "([^\"]*)" tickets$/ do |qty, ticket_class_code|
  fill_in "ticket_order_ticket_line_items_attributes_0_ticket_class_code", :with=>ticket_class_code
  fill_in "ticket_order_ticket_line_items_attributes_0_ticket_count", :with=>qty
end

When /^I enter a membership offer "(.*?)"$/ do |offer_name|
  fill_in "Name", :with => offer_name
  fill_in "membership_offer_recurring_cost", :with=>"10.00"
  fill_in "Tickets per performance", :with=>"1"
  select "PASS", :from=>"Use ticket class code"
  select "PASSFRIEND", :from=>"Use member friend code"
end

Given /^I allow ([^\s]*) payments for the public$/ do |payment_type|
  check "payment_type_allow_for_public"
end

Given /^I disallow ([^\s]*) payments for the public$/ do |payment_type|
  uncheck "payment_type_allow_for_public"
end


Given /^an external payment type "([^\"]*?)" restricted to ticket classes starting with "([^\"]*?)" exists$/ do |external_payment_name, restrict_to|
  FactoryGirl.create(:external_payment_type, :display_name=>external_payment_name, :allow_for_public=>false, :allow_for_box_office=>true, :restrict_to_ticket_classes=>'CHEAP')
end

Given /^an external payment type "([^\"]*?)" exists$/ do |external_payment_name|
  FactoryGirl.create(:external_payment_type, :display_name=>external_payment_name, :allow_for_public=>false, :allow_for_box_office=>true)
end

Given /^I add a note$/ do
  click_link("Add note")
end

Given /^I edit the note to read "(.*?)"$/ do |new_note|
  fill_in "notes", :with=>new_note
end


Given /^the performance "(.*?)" has a ticket class code "(.*?)"$/ do |perf_code, ticket_class_code|
  @performance = Performance.find_by_performance_code(perf_code)
  without_access_control do
    @performance.ticket_class_allocations << FactoryGirl.create(:ticket_class_allocation, :available=>true, :ticket_class=>TicketClass.find_by_class_code(ticket_class_code))
    @performance.save!
  end

end


Transform /^the (\d+)(?:st|nd|rd|th) address tag$/ do |num|
  "ul.address_tags li:nth-child(#{num})"
end

#Transform /^the first address tag label$/ do
#  "$(\"#address_tags input\")[0]"
#end


Given /^I add a tag "(.*?)" to the first address tag label$/ do |label|
  save_and_open_page
  click_link("Add a tag")

  fill_in "#address_tags input:nth-of-type(1)", :with=>label
end


