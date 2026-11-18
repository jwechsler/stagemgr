# Steps for features/admin_resend_confirmation.feature (admin Resend
# Confirmation, a plain data-confirm GET link answered through the shared
# reveal dialog).

def confirmation_emails_for(order)
  ActionMailer::Base.deliveries.select do |mail|
    mail.to == [order.address.email] && mail.subject.start_with?("Your reservation ##{order.id} ")
  end
end

def expect_confirmation_baseline_noted
  return unless @confirmation_emails_before.nil?

  raise 'No baseline recorded: add the step "I note how many confirmation emails that order has been sent" before the action'
end

# The admin page of a sold reserved-seating order includes reseating.js (the
# seat-change script) beside the layout's application bundle.
Then(/^the order page loads reseating\.js$/) do
  expect(page).to have_css('script[src*="/reseating"]', visible: :all)
end

Then(/^I note how many confirmation emails that order has been sent$/) do
  @confirmation_emails_before = confirmation_emails_for(@order).size
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
  expect_confirmation_baseline_noted
  expect(confirmation_emails_for(@order).size).to eq(@confirmation_emails_before + 1)
end

Then(/^no confirmation email has been sent for that order$/) do
  expect_confirmation_baseline_noted
  expect(confirmation_emails_for(@order).size).to eq(@confirmation_emails_before)
end
