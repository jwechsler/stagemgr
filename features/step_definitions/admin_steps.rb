def enter_base_production(code, capacity = 99)
  fill_in "Production code", :with=>code
  fill_in "Name", :with=>"Production #{code}"
  fill_in "Capacity", :with=>capacity
  fill_in "Season", :with=>Date.today.year
  select "Space 1", :from=>"Venue"
end

Given /^I enter a performance on "(.*?)" with code "(.*?)"$/ do |perf_date, perf_code|
  select_date_by_id perf_date, "performance_performance_date"
  select "Active", :from=>"Status"
  fill_in "Performance code", :with=>perf_code
  check "performance_ticket_class_allocations_attributes_0_available"
end

Given /^I enter a production with code "(.*?)" and [|a ] capacity of "(.*?)"$/ do |code, capacity|
  enter_base_production(code, capacity)
end

Given /^I enter a complete production with code "(.*?)"$/ do |code|
  enter_base_production(code)
  fill_in "Credit lines", :with=>"by Willard Shakepare"
  select_date_by_id("#{Date.today.year}/01/01", "production_first_preview_at")
  select_date_by_id("#{Date.today.year}/01/01", "production_press_opening_at")
  select_date_by_id("#{Date.today.year}/01/01", "production_opening_at")
  select_date_by_id("#{Date.today.year}/01/01", "production_closing_at")
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
  select "MEMBER", :from=>"Use ticket class code"
  select "MEMBERFRIEND", :from=>"Use member friend code"
end
