Given /^I enter a performance on "(.*?)" with code "(.*?)"$/ do |perf_date, perf_code|
  select_date_by_id perf_date, "performance_performance_date"
  select "Active", :from=>"Status"
  fill_in "Performance code", :with=>perf_code
  check "performance_ticket_class_allocations_attributes_0_available"
end
