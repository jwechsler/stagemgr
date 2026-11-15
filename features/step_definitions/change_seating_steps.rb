# Steps for features/admin_change_seating.feature (admin Change Seating,
# reseating.js -> SeatAssignment.reseating_commit).

def change_seating_circle(seat_id, status = nil)
  "#change-seats #seatingmap circle#{".#{status}" if status}[data-assignment-id='#{seat_id}']"
end

When(/^I open Change Seating$/) do
  find('#seating-control').click
  expect(page).to have_css('#change-seats', visible: true)
  @old_seat_id = @original_seat_ids.first
  @old_line_item = TicketLineItem.find_by!(seat_assignment_id: @old_seat_id)
  expect(page).to have_css(change_seating_circle(@old_seat_id, 'assigned'))
end

When(/^I move the order's first seat to an open seat$/) do
  find(change_seating_circle(@old_seat_id)).click
  expect(page).to have_css(change_seating_circle(@old_seat_id, 'releasing'))
  target = find('#change-seats #seatingmap circle.available[data-assignment-id]', match: :first)
  @new_seat_id = target['data-assignment-id'].to_i
  target.click
  expect(page).to have_css(change_seating_circle(@new_seat_id, 'assigned'))
  expect(page).to have_css('#finalize-seating:not(.disabled)')
  expect_no_reveal_alert
end

When(/^I finalize the new seating$/) do
  find('#finalize-seating').click
  @new_location = SeatAssignment.find(@new_seat_id).seat.location
  expect(page).to have_css('#seatinglist', text: @new_location)
  expect_no_reveal_alert
end

Then(/^the first seat's line item holds the new seat$/) do
  expect(@old_line_item.reload.seat_assignment_id).to eq(@new_seat_id)
  expect(SeatAssignment.find(@new_seat_id)).to have_attributes(status: SeatAssignment::ASSIGNED,
                                                               order_id: @order.id,
                                                               ticket_class_id: @old_line_item.ticket_class_id)
end

Then(/^the old seat is available with no line item on it$/) do
  expect(SeatAssignment.find(@old_seat_id)).to have_attributes(status: SeatAssignment::AVAILABLE,
                                                               order_uuid: nil, order_id: nil)
  expect(LineItem.where(seat_assignment_id: @old_seat_id)).to be_empty
end

Then(/^the order page shows the new seat location$/) do
  old_location = SeatAssignment.find(@old_seat_id).seat.location
  visit admin_ticket_order_path(@order)
  expect(page).to have_css('#seatinglist', text: @new_location)
  expect(find('#seatinglist').text.split(',')).not_to include(old_location)
end

# Records the URL of every XHR the page opens, below jQuery: the order page
# loads jQuery twice (reseating.js requires seat_map.js, which requires
# application.js), and this sees $.post from either copy.
SEATING_REQUEST_RECORDER_JS = <<~JS.freeze
  (function() {
    window.__seatingRequests = [];
    var realOpen = XMLHttpRequest.prototype.open;
    XMLHttpRequest.prototype.open = function(method, url) {
      window.__seatingRequests.push(String(url));
      return realOpen.apply(this, arguments);
    };
  })();
JS

# Foundation sets aria-hidden="true" in the same callback that fires
# closed.zf.reveal, so once it is set the close handlers have run.
def expect_reveal_finished_closing(selector)
  expect(page.document).to have_css("#{selector}[aria-hidden='true']", visible: :all)
end

def seating_requests
  page.evaluate_script('window.__seatingRequests')
end

def seating_request_count(data_attribute)
  url = find('#seating-config', visible: :all)[data_attribute]
  seating_requests.count(url)
end

def seat_statuses(*seat_ids)
  SeatAssignment.where(id: seat_ids).to_h { |sa| [sa.id, sa.status] }
end

When(/^I record the page's seating requests$/) do
  expect(page).to have_css('#seating-control')
  page.execute_script(SEATING_REQUEST_RECORDER_JS)
end

When(/^I open Change Seating again$/) do
  expect(page).to have_no_css('#change-seats', visible: true)
  find('#seating-control').click
  expect(page).to have_css('#change-seats', visible: true)
end

When(/^I move the new seat to another open seat$/) do
  @first_new_seat_id = @new_seat_id
  find(change_seating_circle(@first_new_seat_id, 'assigned')).click
  expect(page).to have_css(change_seating_circle(@first_new_seat_id, 'releasing'))
  target = find('#change-seats #seatingmap circle.available[data-assignment-id]', match: :first)
  @second_new_seat_id = target['data-assignment-id'].to_i
  target.click
  expect(page).to have_css(change_seating_circle(@second_new_seat_id, 'assigned'))
  expect_no_reveal_alert
end

When(/^I pick one more open seat than the order has tickets$/) do
  extra = find('#change-seats #seatingmap circle.available[data-assignment-id]', match: :first)
  @extra_seat_id = extra['data-assignment-id'].to_i
  extra.click
end

When(/^I close Change Seating without finalizing$/) do
  # The X button is the modal's explicit close control.
  find('#change-seats > button.close-button[data-close]').click
  expect(page).to have_no_css('#change-seats', visible: true)
  expect_reveal_finished_closing('#change-seats')
end

When(/^I press Esc in Change Seating$/) do
  # Esc still closes the modal (Foundation closeOnEsc).
  page.send_keys(:escape)
  expect(page).to have_no_css('#change-seats', visible: true)
  expect_reveal_finished_closing('#change-seats')
end

Then(/^I dismiss the notice "(.*?)"$/) do |message|
  expect(accept_reveal_alert(message)).to eq(message)
  expect_reveal_finished_closing(RevealConfirmHelpers::REVEAL_CONFIRM_SELECTOR)
end

Then(/^Change Seating has closed$/) do
  expect(page).to have_no_css('#change-seats', visible: true)
  expect_reveal_finished_closing('#change-seats')
  expect(page).to have_css('#seatinglist', text: @new_location)
end

Then(/^Change Seating is still open$/) do
  expect(page).to have_css('#change-seats', visible: true)
  expect(page).to have_css("#change-seats[aria-hidden='false']")
end

Then(/^an? (commit|rollback) request was sent$/) do |kind|
  attribute = "data-#{kind}-reseating-url"
  wait_for_condition { seating_request_count(attribute) == 1 }
  expect(seating_request_count(attribute)).to eq(1)
end

Then(/^no rollback request was sent$/) do
  expect(seating_requests).not_to be_empty
  expect(seating_request_count('data-rollback-reseating-url')).to eq(0)
end

Then(/^the move is pending$/) do
  expect(SeatAssignment.find(@old_seat_id)).to have_attributes(status: SeatAssignment::RELEASING,
                                                               order_uuid: @order.uuid)
  expect(SeatAssignment.find(@new_seat_id)).to have_attributes(status: SeatAssignment::TEMPORARY,
                                                               order_uuid: @order.uuid)
  expect(@old_line_item.reload.seat_assignment_id).to eq(@old_seat_id)
end

Then(/^the second move is pending$/) do
  expect(SeatAssignment.find(@first_new_seat_id)).to have_attributes(status: SeatAssignment::RELEASING,
                                                                     order_uuid: @order.uuid)
  expect(SeatAssignment.find(@second_new_seat_id)).to have_attributes(status: SeatAssignment::TEMPORARY,
                                                                      order_uuid: @order.uuid)
end

Then(/^the old seat is back on the order and the new seat is open again$/) do
  settled = { @old_seat_id => SeatAssignment::ASSIGNED, @new_seat_id => SeatAssignment::AVAILABLE }
  wait_for_condition { seat_statuses(@old_seat_id, @new_seat_id) == settled }
  # order_id is not asserted: the order fixture never sets it on its seats.
  expect(SeatAssignment.find(@old_seat_id)).to have_attributes(status: SeatAssignment::ASSIGNED,
                                                               order_uuid: @order.uuid)
  expect(SeatAssignment.find(@new_seat_id)).to have_attributes(status: SeatAssignment::AVAILABLE, order_uuid: nil)
  expect(@old_line_item.reload.seat_assignment_id).to eq(@old_seat_id)
end

Then(/^the second move was rolled back, keeping the first$/) do
  settled = { @first_new_seat_id => SeatAssignment::ASSIGNED, @second_new_seat_id => SeatAssignment::AVAILABLE }
  wait_for_condition { seat_statuses(@first_new_seat_id, @second_new_seat_id) == settled }
  expect(SeatAssignment.find(@first_new_seat_id)).to have_attributes(status: SeatAssignment::ASSIGNED,
                                                                     order_uuid: @order.uuid, order_id: @order.id)
  expect(SeatAssignment.find(@second_new_seat_id)).to have_attributes(status: SeatAssignment::AVAILABLE,
                                                                      order_uuid: nil)
  expect(@old_line_item.reload.seat_assignment_id).to eq(@first_new_seat_id)
  expect(SeatAssignment.find(@old_seat_id)).to have_attributes(status: SeatAssignment::AVAILABLE, order_uuid: nil)
end
