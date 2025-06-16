Given /^I am logged in as an administrator$/ do
  @current_test_user = Factory(:admin_user)
  visit new_user_session_path
  fill_in('Email', :with => @current_test_user.email)
  fill_in('Password', :with => 'password')
  click_button('Login')
end

Given /^there is a theater named "([^"]*)"$/ do |theater_name|
  Factory(:theater, name: theater_name)
end

Given /^there is a flex pass offer named "([^"]*)"$/ do |offer_name|
  theater = Theater.first || Factory(:theater)
  Factory(:flex_pass_offer, 
    name: offer_name,
    theater: theater,
    price: 100.00,
    facility_fee: 2.00,
    spiff: 1.00,
    flat_payout: 5.00
  )
end

When /^I go to the new admin flex pass offer page$/ do
  visit new_admin_flex_pass_offer_path
end

When /^I go to the edit admin flex pass offer page for "([^"]*)"$/ do |offer_name|
  offer = FlexPassOffer.find_by(name: offer_name)
  visit edit_admin_flex_pass_offer_path(offer)
end