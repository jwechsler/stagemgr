# Donation Steps

Given /^I choose the "(.*?)" donation level$/ do |amount|
  choose amount
end

Given /^I enter "(.*?)" as a donation amount$/ do |amt|
  fill_in 'other amount', :with=>amt
end

Given /^I select the monthly pledge option$/ do
  follow "Monthly"
end

