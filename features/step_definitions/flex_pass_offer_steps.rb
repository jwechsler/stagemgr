Given(/^I am logged in as an administrator$/) do
  @current_test_user = FactoryBot.create(:admin_user)
  visit new_user_session_path
  fill_in('Email', with: @current_test_user.email)
  fill_in('Password', with: 'password')
  click_button('Login')
end

Given(/^there is a theater named "([^"]*)"$/) do |theater_name|
  FactoryBot.create(:theater, name: theater_name)
end

Given(/^there is a default ticket class with code "([^"]*)"$/) do |code|
  FactoryBot.create(:default_ticket_class, class_code: code, class_name: "#{code} Ticket")
end

Given(/^there is a flex pass offer named "([^"]*)"$/) do |offer_name|
  theater = Theater.first || FactoryBot.create(:theater)
  FactoryBot.create(:flex_pass_offer,
                    name: offer_name,
                    theater: theater,
                    price: 100.00,
                    facility_fee: 2.00,
                    spiff: 1.00,
                    flat_payout: 5.00)
end

When(/^I select the "([^"]*)" row in the active flex pass offers table$/) do |offer_name|
  row = find('#active_flex_pass_offer_listing tbody tr', text: offer_name)
  # The price cell: clicking the offer name would follow its link.
  row.find('td:nth-child(2)').click
  expect(row).to match_css('tr.selected')
end

When(/^I click the "([^"]*)" bulk action$/) do |action|
  click_button(action)
end

When(/^I (confirm|cancel) making (\d+) flex pass offers? inactive$/) do |answer, count|
  question = "Make #{count} offer#{'s' unless count.to_i == 1} inactive? Inactive offers also come off public sale."
  if answer == 'confirm'
    accept_reveal_confirm(question, accept_label: 'Make Inactive')
  else
    dismiss_reveal_confirm(question)
  end
end

Then(/^I should see the offer bulk result "([^"]*)"$/) do |message|
  expect(page).to have_css('.offer-bulk-result.success', text: message)
end

Then(/^I should not see an offer bulk result$/) do
  expect(page).to have_no_css('.offer-bulk-result')
end

Then(/^the flex pass offer "([^"]*)" should be (active|inactive)$/) do |offer_name, state|
  expect(FlexPassOffer.find_by!(name: offer_name).active).to eq(state == 'active')
end
