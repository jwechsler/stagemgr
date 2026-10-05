Given(/^there is an inactive membership offer named "([^"]*)"$/) do |offer_name|
  FactoryBot.create(:membership_offer, name: offer_name, status: MembershipOffer::INACTIVE)
end

Given(/^I have run the membership analysis for "([^"]*)" and "([^"]*)"$/) do |first, second|
  [first, second].each do |offer_name|
    step %(I search the offer picker in "#membership-analysis-form" for "#{offer_name}")
    step %(I choose "#{offer_name}" from the offer picker suggestions)
  end
  click_button 'Run'
  step 'I should see the membership analysis results'
end

When(/^I change the membership analysis start date to "([^"]*)"$/) do |date|
  find_by_id('starting_date').set(date)
end

Then(/^I should see the offer picker suggestions "([^"]*)"$/) do |labels|
  expected = labels.split(', ')
  expect(page).to have_css('ul.ui-autocomplete li', count: expected.size, wait: 5)
  expect(all('ul.ui-autocomplete li').map(&:text)).to eq(expected)
end

Then(/^I should see the membership analysis results$/) do
  expect(page).to have_css('#membership-analysis-results')
end

Then(/^I should not see the membership analysis results$/) do
  expect(page).to have_no_css('#membership-analysis-results')
end
