# Steps for the shared confirmation dialog's default action and focus
# handling (reveal_confirm.js). Selectors live in
# features/support/reveal_confirm.rb.

REVEAL_CONFIRM_DEFAULT_ACTIONS = { 'OK' => :accept, 'Cancel' => :cancel }.freeze

Then(/^the confirmation "([^"]*)" defaults to (OK|Cancel)$/) do |question, button|
  expect_reveal_confirm_default(REVEAL_CONFIRM_DEFAULT_ACTIONS.fetch(button), question)
end

Then(/^the confirmation's accept button reads "([^"]*)"$/) do |label|
  expect_reveal_confirm_accept_label(label)
end

When(/^I press Enter in the confirmation$/) do
  press_enter_on_reveal_confirm
end

When(/^I click outside the confirmation$/) do
  click_reveal_confirm_overlay
end

When(/^I follow "([^"]*)" and confirm with "([^"]*)"$/) do |link_text, accept_label|
  click_link link_text
  accept_reveal_confirm(nil, accept_label: accept_label)
end

Then(/^the confirmation is not showing$/) do
  expect_no_reveal_confirm
end

Then(/^the "([^"]*)" link has focus$/) do |link_text|
  expect(page).to have_link(link_text, focused: true)
end
