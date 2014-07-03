
Given /^I enter a performance on "(.*?)" with code "(.*?)"$/ do |perf_date, perf_code|
  fill_in "performance_performance_date", :with=>perf_date
  select "Active", :from=>"Status"
  fill_in "Performance code", :with=>perf_code
end

Given /^I enter a performance date of "(.*?)"$/ do |perf_date|
  fill_in "Performance date", :with=>perf_date
end

Given /^I enter a trigger to "(.*?)" based on "(.*?)" days before for the (\d+)(?:st|nd|rd|th) ticket class$/ do |code, value, num|
  fill_in "performance_ticket_class_allocations_attributes_#{num}_shift_days_before_performance", :with=>value
  fill_in "performance_ticket_class_allocations_attributes_#{num}_shift_to_code", :with=>code
  check "performance_ticket_class_allocations_attributes_#{num}_shiftable"
end

Given /^I enter a trigger to "(.*?)" based on capacity of "(.*?)" for the (\d+)(?:st|nd|rd|th) ticket class$/ do |code, value, num|
  fill_in "performance_ticket_class_allocations_attributes_#{num}_shift_when_capacity_over", :with=>value
  fill_in "performance_ticket_class_allocations_attributes_#{num}_shift_to_code", :with=>code
  check "performance_ticket_class_allocations_attributes_#{num}_shiftable"
end

Given /^I enter a custom feature "(.*?)" with a description of "(.*?)"$/ do |short_name, description|
  fill_in "performance_special_feature_short_markdown", :with=>short_name
  fill_in "performance_special_feature_full_markdown", :with=>description

  pending # express the regexp above with the code you wish you had
end


Then(/^show me the yaml for performance "(.*?)"$/) do |perf_code|
  p = Performance.find_by_performance_code(perf_code)
  puts p.to_yaml
  puts "ticket class allocations"
  puts p.ticket_class_allocations.to_yaml
  puts p.ticket_classes.to_yaml
end
