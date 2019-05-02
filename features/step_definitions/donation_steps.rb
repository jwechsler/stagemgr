# Donation Steps

Given /^I choose the "(.*?)" donation level$/ do |amount|
  choose amount
end

Given /^I enter "(.*?)" as a monthly pledge amount$/ do |amount|
  fill_in 'other monthly amount', :with=>amount
end

Given /^I enter "(.*?)" as a donation amount$/ do |amt|
  choose "Other Amount (below)"
  fill_in 'donation_order_donation_line_items_attributes_0_amount', :with=>amt
end

