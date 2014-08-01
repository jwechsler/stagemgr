
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

Given(/^I suppress the "(.*?)" method for "(.*?)"$/) do |method_name, task_type|
  click_link("add suppression")
  find('.new_order_task_suppression_task_type input').find(:option,task_type,{}).select_option
  find('.new_order_task_suppression_method_name input').find(:option,method_name,{}).select_option
end

Then(/^I delete the first order task suppression$/) do
  check "payment_type_order_task_suppressions_attributes_0__destroy"
end