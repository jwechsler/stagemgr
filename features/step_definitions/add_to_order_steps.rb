# Steps for features/admin_add_to_order.feature (box office Add to Order).

# 1x1 transparent PNG. The seat map only needs an attached image and its
# recorded size to draw the SVG; the seats are plotted over it.
SEAT_MAP_PNG = Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==')

Given(/^the seat map for "(.*?)" is plotted$/) do |production_name|
  seat_map = Production.find_by(name: production_name).seat_map
  # Attached directly with its size recorded: SeatMap#save_image_dimensions
  # would run the image analyzer, which needs MiniMagick.
  blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(SEAT_MAP_PNG), filename: 'seat-map.png',
                                                content_type: 'image/png',
                                                metadata: { identified: true, analyzed: true, width: 480, height: 80 })
  ActiveStorage::Attachment.create!(name: 'base_image_map', record: seat_map, blob: blob)
  seat_map.seats.order(:seat_number).each_with_index do |seat, index|
    seat.update!(origin_x: 24 + (index * 46), origin_y: 40, width: 14, height: 14)
  end
end

Given(/^a "(.*?)" add-on costing (\d+) is on sale for "(.*?)"$/) do |class_name, price, perf_code|
  performance = Performance.find_by(performance_code: perf_code)
  add_on = TicketClass.create!(production: performance.production, class_code: 'TABLET', class_name: class_name,
                               ticket_price: price.to_i, ticket_type: 'Fixed', ticketing_fee: 0.0,
                               holds_seats: false, web_visible: false)
  allocation = TicketClassAllocation.find_or_initialize_by(performance: performance, ticket_class: add_on)
  allocation.update!(available: true)
end

Given(/^a processed order for (\d+) "(.*?)" seats at "(.*?)" paid in cash$/) do |count, class_code, perf_code|
  performance = Performance.find_by(performance_code: perf_code)
  ticket_class = performance.production.ticket_classes.find_by(class_code: class_code)
  cash = CashPaymentType.find_or_create_by!(display_name: 'Cash') { |type| type.allow_for_box_office = true }
  @order = TicketOrder.new(status: Order::NEW, performance: performance, payment_type: cash,
                           address: FactoryBot.create(:address))
  seats = performance.seat_assignments.where(status: SeatAssignment::AVAILABLE).order(:id).first(count.to_i)
  seats.each do |seat|
    seat.update!(status: SeatAssignment::ASSIGNED, order_uuid: @order.uuid, ticket_class_id: ticket_class.id)
    @order.ticket_line_items.build(ticket_class: ticket_class, ticket_count: 1, seat_assignment_id: seat.id)
  end
  @order.save!
  @order.payments << CashPayment.new(amount: @order.total_due, payment_type: cash, order: @order)
  @order.update!(status: Order::PROCESSED)
  @original_seat_ids = seats.map(&:id)
end

When(/^I visit the admin page for that order$/) do
  visit admin_ticket_order_path(@order)
end

# The order page reloads its seat map and ticket classes over ajax shortly
# after it opens (update_ticketing_panel); wait for that before clicking.
Then(/^the order's current seats show as taken on the seat map$/) do
  expect(page).to have_css('#addition-banner')
  Timeout.timeout(Capybara.default_max_wait_time) do
    sleep 0.1 until page.evaluate_script("typeof $('#ticket-items').data('line-items') === 'string'")
  end
  @original_seat_ids.each do |id|
    expect(page).to have_css("#seatingmap circle.unavailable[data-assignment-id='#{id}']")
  end
end

When(/^I place the order and confirm$/) do
  accept_confirm { click_link 'Place Order' }
end

When(/^I add the "(.*?)" add-on$/) do |class_name|
  find('#non-seat-ticket-rows .grid-x', text: class_name).click_link('Add')
  expect(page).to have_css('#ticket-display .non-seat-ticket', text: class_name)
end

When(/^I pick an open seat as "(.*?)"$/) do |class_name|
  seat = find("#seatingmap circle.available[data-assignment-id]", match: :first)
  @added_seat_id = seat['data-assignment-id'].to_i
  seat.click
  within('#ticket-modal') do
    find('#ticket-selector .grid-x', text: class_name).click_link('Select')
  end
  expect(page).to have_css("#ticket-display .ticket_line_item[data-seat-assignment-id='#{@added_seat_id}']")
end

Then(/^the order total should be "(.*?)"$/) do |amount|
  expect(page).to have_css('#order_total', text: amount)
end

# The addition is deleted once merged; the order's audit trail names it.
Then(/^the order's history records the addition, which is gone$/) do
  expect(page).to have_content(/Added from order #\d+: .*Captioning tablet/)
  expect(TicketOrder.where(performance_id: @order.performance_id).pluck(:id)).to eq([@order.id])
end

Then(/^the order should have (\d+) "(.*?)" and (\d+) "(.*?)" tickets$/) do |add_on_count, add_on, seat_count, seat_class|
  counts = @order.reload.ticket_line_items.group_by { |tli| tli.ticket_class.class_name }
                                          .transform_values { |items| items.sum(&:ticket_count) }
  expect(counts[add_on]).to eq(add_on_count.to_i)
  expect(counts[seat_class]).to eq(seat_count.to_i)
  expect(@order.total_due).to eq(@order.total_paid)
end

Then(/^the order's original seats are unchanged and the new seat is assigned$/) do
  seats = SeatAssignment.where(id: @original_seat_ids + [@added_seat_id])
  expect(seats.map(&:status).uniq).to eq([SeatAssignment::ASSIGNED])
  expect(seats.map(&:order_uuid).uniq).to eq([@order.uuid])
end
