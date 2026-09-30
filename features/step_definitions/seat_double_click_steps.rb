# Steps for features/seat_double_click.feature.

Given(/^"(.*?)" tickets are sold online with public credit card payments$/) do |class_code|
  @production.ticket_classes.find_by!(class_code: class_code).update!(web_visible: true)
  FactoryBot.create(:credit_card_payment_type, allow_for_public: true)
end

# Counts reserve posts from here on, so a scenario can assert how many a
# gesture sent.
When(/^I count seat reserve requests$/) do
  expect(page).to have_css('#seatingmap circle.available[data-assignment-id]')
  page.execute_script(<<~JS)
    window.__reserveRequests = 0;
    $(document).ajaxSend(function(_e, _xhr, settings) {
      if (settings.url.indexOf('reserve') !== -1) { window.__reserveRequests += 1; }
    });
  JS
end

When(/^I double-click "(.*?)" for an open seat$/) do |class_name|
  seat = find('#seatingmap circle.available[data-assignment-id]', match: :first)
  @picked_seat_id = seat['data-assignment-id'].to_i
  seat.click
  button = within('#ticket-modal') { find('#ticket-selector .grid-x', text: class_name).find_link('Select') }
  # Two clicks in one task: the second lands before the modal's close takes
  # effect, as a fast real double click does. (WebDriver's double_click lets
  # the modal close in between, so it never reaches the button twice.)
  page.execute_script('arguments[0].click(); arguments[0].click();', button)
  expect(page).to have_css("#ticket-display .ticket_line_item[data-seat-assignment-id='#{@picked_seat_id}']")
  # Let any second request settle before counting.
  expect(page).to have_no_css('#seatingmap circle.seat-pending')
end

Then(/^the seat has one ticket row and one reserve request was sent$/) do
  rows = all("#ticket-display .ticket_line_item[data-seat-assignment-id='#{@picked_seat_id}']")
  expect(rows.size).to eq(1)
  expect(page.evaluate_script('window.__reserveRequests')).to eq(1)
end

Then(/^the picked seat has one line item on the order$/) do
  tlis = TicketLineItem.where(seat_assignment_id: @picked_seat_id)
  expect(tlis.count).to eq(1)
  expect(tlis.first.order_id).not_to be_nil
  expect(tlis.first.ticket_count).to eq(1)
end
