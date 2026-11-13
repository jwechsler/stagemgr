# Steps for features/admin_cancel_order.feature (Cancel Order on an admin
# ticket order). The held order comes from
# "the performance ... has N held seats with a valid HOLD order".
#
# A Hold, New or Processing order is editable, so its show page redirects to
# the edit page (OrdersController#redirect_edits_to_proper_action): the Cancel
# Order a clerk can reach is the one in admin/ticket_orders/_order_actions.

When(/^I visit the admin page for the held order$/) do
  @orders_before_cancel = Order.count
  visit admin_ticket_order_path(@test_order)
  expect(page).to have_current_path(edit_admin_ticket_order_path(@test_order))
  expect(page).to have_link('Cancel Order')
end

Then(/^the held order is still on hold$/) do
  expect(page).to have_current_path(edit_admin_ticket_order_path(@test_order))
  expect(page).to have_link('Cancel Order')
  expect(Order.where(id: @test_order.id).pick(:status)).to eq(Order::HOLD)
  expect(Order.count).to eq(@orders_before_cancel)
end

# seat_assignment.js requires seat_map.js, which requires application.js, so
# jQuery, jquery_ujs and reveal_confirm.js are evaluated twice on this page.
Then(/^the order page loads seat_assignment\.js$/) do
  expect(page).to have_css('script[src*="/seat_assignment"]', visible: :all)
end

# OrdersController#cancel destroys an unpaid order and redirects to the
# orders list; a second POST would find no order and fail.
Then(/^the held order has been cancelled once$/) do
  expect(page).to have_current_path(admin_orders_path)
  expect(page).to have_no_css('.flash_error')
  expect(Order.exists?(@test_order.id)).to be(false)
  expect(Order.count).to eq(@orders_before_cancel - 1)
end
