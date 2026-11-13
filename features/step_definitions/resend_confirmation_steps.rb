# Steps for features/admin_resend_confirmation.feature (admin Resend
# Confirmation, a plain data-confirm GET link answered through the shared
# reveal dialog).

def confirmation_emails_for(order)
  ActionMailer::Base.deliveries.select do |mail|
    mail.to == [order.address.email] && mail.subject.start_with?("Your reservation ##{order.id} ")
  end
end

# reseating.js requires seat_map.js, which requires application.js: with it on
# the page jQuery, jquery_ujs and reveal_confirm.js are each evaluated twice.
Then(/^the order page loads reseating\.js$/) do
  expect(page).to have_css('script[src*="/reseating"]', visible: :all)
  @confirmation_emails_before = confirmation_emails_for(@order).size
end

When(/^I follow "([^"]*)" and answer "([^"]*)" with (OK|Cancel)$/) do |link_text, question, answer|
  click_link link_text
  answer == 'OK' ? accept_reveal_confirm(question) : dismiss_reveal_confirm(question)
end

Then(/^I should see the notice "([^"]*)"$/) do |text|
  expect(page).to have_css('.flash_notice', text: text)
end

Then(/^I should not see the notice "([^"]*)"$/) do |text|
  expect(page).to have_no_css('.flash_notice', text: text)
end

Then(/^the resend confirmation question is not showing$/) do
  expect_no_reveal_confirm
end

Then(/^I am still on the admin page for that order$/) do
  expect(page).to have_current_path(admin_ticket_order_path(@order))
  expect(page).to have_link('Resend Confirmation')
end

Then(/^one confirmation email has been sent for that order$/) do
  expect(confirmation_emails_for(@order).size).to eq(@confirmation_emails_before + 1)
end

Then(/^no confirmation email has been sent for that order$/) do
  expect(confirmation_emails_for(@order).size).to eq(@confirmation_emails_before)
end
