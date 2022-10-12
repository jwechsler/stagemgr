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

Then('a donation order for {string} exists') do |string|
  count = DonationLineItem.where(amount: string.to_f).count
  raise "A donation for #{string} can't be found" if count.eql?(0)
end

