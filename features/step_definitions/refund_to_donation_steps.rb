# Steps for features/admin_refund_to_donation.feature (Refund to Donation, a
# data-method POST link with a data-confirm question, on the admin page of a
# processed reserved-seating order).
#
# That page loads reseating.js, which bundles application.js a second time,
# so two jquery_ujs copies could each submit the link's hidden form. The
# request counter below sees every convert_to_donation request the test
# server handles, from either copy.

CONVERT_TO_DONATION_CONTROLLER = 'Admin::TicketOrdersController'.freeze
CONVERT_TO_DONATION_ACTION = 'convert_to_donation'.freeze

Given(/^that order's theater accepts donations$/) do
  @order.theater.update!(accepts_donations: true)
  expect(@order.reload).to be_convertible_to_donation
end

# The Capybara server runs in this process, so its controller notifications
# reach this subscriber. Counted under a mutex: the server thread writes it.
Given(/^I count the requests that convert an order to a donation$/) do
  @donation_orders_before = DonationOrder.count
  @convert_requests = []
  lock = Mutex.new
  @convert_requests_lock = lock
  requests = @convert_requests
  @convert_subscriber = ActiveSupport::Notifications.subscribe('process_action.action_controller') do |*, payload|
    next unless payload[:controller] == CONVERT_TO_DONATION_CONTROLLER &&
                payload[:action] == CONVERT_TO_DONATION_ACTION

    lock.synchronize { requests << payload[:params]['id'] }
  end
end

After do
  ActiveSupport::Notifications.unsubscribe(@convert_subscriber) if @convert_subscriber
end

# Two evaluations of reveal_confirm.js must still leave a single dialog.
Then(/^the page has one confirmation dialog, asking "([^"]*)"$/) do |question|
  reveal_confirm_dialog(question)
  expect(page.document).to have_css(RevealConfirmHelpers::REVEAL_CONFIRM_SELECTOR, count: 1, visible: :all)
end

When(/^I answer the open confirmation "([^"]*)" with (OK|Cancel)$/) do |question, answer|
  answer_reveal_confirm_with(question, answer)
end

Then(/^the new donation order's page opens$/) do
  expect(page).to have_css('.flash_notice', text: "Order ##{@order.id} converted to Donation #")
  expect(page).to have_no_css('.flash_error')
  @donation = DonationOrder.where(production_id: @order.performance.production_id).order(:id).last
  expect(@donation).not_to be_nil
  expect(page).to have_current_path(admin_donation_order_path(@donation))
end

# Waits for every request the test server is still handling, so a second
# submission that reached the server cannot finish after the count is read.
Then(/^exactly one request converted the order to a donation$/) do
  page.server.wait_for_pending_requests
  order_ids = @convert_requests_lock.synchronize { @convert_requests.dup }
  expect(order_ids).to eq([@order.id.to_s])
end

Then(/^the order has been converted to exactly one donation$/) do
  expect(DonationOrder.count).to eq(@donation_orders_before + 1)
  @order.reload
  expect(@order.status).to eq(Order::CANCELED)
  expect(@order.ticket_line_items).to be_empty
  expect(@order.notes.scan('Converted to Donation Order').size).to eq(1)
  expect(@order.payments).to be_empty
  expect(@donation.payments.count).to eq(1)
  expect(@donation.donation_line_items.count).to eq(1)
end
