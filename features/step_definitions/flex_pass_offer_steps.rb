Given /^I am logged in as an administrator$/ do
  @current_test_user = FactoryBot.create(:admin_user)
  visit new_user_session_path
  fill_in('Email', :with => @current_test_user.email)
  fill_in('Password', :with => 'password')
  click_button('Login')
end

Given /^there is a theater named "([^"]*)"$/ do |theater_name|
  FactoryBot.create(:theater, name: theater_name)
end

Given /^there is a default ticket class with code "([^"]*)"$/ do |code|
  FactoryBot.create(:default_ticket_class, class_code: code, class_name: "#{code} Ticket")
end

Given /^there is a flex pass offer named "([^"]*)"$/ do |offer_name|
  theater = Theater.first || FactoryBot.create(:theater)
  FactoryBot.create(:flex_pass_offer,
    name: offer_name,
    theater: theater,
    price: 100.00,
    facility_fee: 2.00,
    spiff: 1.00,
    flat_payout: 5.00
  )
end

