# Steps for features/admin_change_seating.feature (admin Change Seating,
# reseating.js -> SeatAssignment.reseating_commit).

def change_seating_circle(seat_id, status = nil)
  "#change-seats #seatingmap circle#{".#{status}" if status}[data-assignment-id='#{seat_id}']"
end

When(/^I open Change Seating$/) do
  # A real alert would block WebDriver; record any instead.
  page.execute_script('window.__alerts = []; window.alert = function(m) { window.__alerts.push(String(m)); };')
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
end

When(/^I finalize the new seating$/) do
  find('#finalize-seating').click
  @new_location = SeatAssignment.find(@new_seat_id).seat.location
  expect(page).to have_css('#seatinglist', text: @new_location)
  expect(page.evaluate_script('window.__alerts')).to eq([])
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
