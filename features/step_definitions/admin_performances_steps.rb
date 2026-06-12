Given /^I enter a performance on "(.*?)" with code "(.*?)"$/ do |perf_date, perf_code|
  fill_in "performance_performance_date", :with => perf_date
  select "Active", :from => "Status"
  fill_in "Performance code", :with => perf_code
end

Given /^I enter a performance date of "(.*?)"$/ do |perf_date|
  fill_in "performance_performance_date", :with => perf_date
  page.execute_script("$('#performance_performance_date').val('#{perf_date}')")
  # find(:css, '#performance_performance_date').value(perf_date)
end

Given /^I enter a trigger to "(.*?)" based on "(.*?)" days before for the (\d+)(?:st|nd|rd|th) ticket class$/ do |code, value, num|
  fill_in "performance_ticket_class_allocations_attributes_#{num - 1}_shift_days_before_performance", :with => value
  select code, :from => "performance_ticket_class_allocations_attributes_#{num - 1}_shift_to_code"
  check "performance_ticket_class_allocations_attributes_#{num - 1}_shiftable"
end

Given /^I enter a trigger to "(.*?)" based on capacity of "(.*?)" for the (\d+)(?:st|nd|rd|th) ticket class$/ do |code, value, num|
  fill_in "performance_ticket_class_allocations_attributes_#{num - 1}_shift_when_capacity_over", :with => value
  select code, :from => "performance_ticket_class_allocations_attributes_#{num - 1}_shift_to_code"
  check "performance_ticket_class_allocations_attributes_#{num - 1}_shiftable"
end

Given /^I enter a custom feature description of "(.*?)"$/ do |description|
  fill_in "performance_special_feature_display_markdown", :with => description
end

Given /^I enter a custom feature email of "(.*?)"$/ do |email|
  fill_in "performance_special_feature_email_markdown", :with => email
end

Then(/^show me the yaml for performance "(.*?)"$/) do |perf_code|
  p = Performance.find_by_performance_code(perf_code)
  puts p.to_yaml
  puts "ticket class allocations"
  puts p.ticket_class_allocations.to_yaml
  puts p.ticket_classes.to_yaml
end

Then (/^the performance date for "(.*?)" is "(.*?)"$/) do |perf_code, required_date|
  raise "unknown performance code" unless (perf = Performance.find_by_performance_code(perf_code))
  raise "expected performance date of #{required_date}, but was #{perf.performance_date}" unless required_date.to_date == perf.performance_date
end

Given(/^I enter an override URL of "(.*?)"$/) do |url|
  fill_in "performance_order_url_override", :with => url
end

# Steps for release held seats feature

Given(/^a theater with reserved seating exists$/) do
  # Use existing theater or create one
  @theater = Theater.first || Theater.create!(
    name: "Test Theater",
    url: "http://test.example.com",
    theater_class: Theater::THEATER_CLASSES.first,
    status: Theater::THEATER_STATUSES.first
  )

  # Create venue (venues are not directly associated with theaters)
  @venue = Venue.find_or_create_by!(name: "Main Venue") do |v|
    v.ordinal_sort = 1
  end

  # Create or get seat map
  @seat_map = @venue.seat_maps.first
  unless @seat_map
    @seat_map = SeatMap.create!(venue: @venue)
    # Create seats
    10.times do |i|
      Seat.create!(seat_map: @seat_map, row: "A", seat_number: (i + 1).to_s, location: "A#{i + 1}")
    end
  end

  # Create production with seat map
  @production = Production.create!(
    name: "Production One",
    production_code: "PROD01",
    status: Production::PRODUCTION_STATUSES.first,
    season: Date.today.year,
    theater: @theater,
    venue: @venue,
    seat_map: @seat_map,
    opening_at: Date.today,
    closing_at: Date.today + 30.days,
    press_opening_at: Date.today,
    first_preview_at: Date.today,
    capacity: @seat_map.seats.count
  )

  # Create default ticket classes
  TicketClass.create!(production: @production, class_code: "ADULT", class_name: "Adult", ticket_price: 25.00,
                      ticket_type: 'Fixed', ticketing_fee: 0.0)
  TicketClass.create!(production: @production, class_code: "SENIOR", class_name: "Senior", ticket_price: 20.00,
                      ticket_type: 'Fixed', ticketing_fee: 0.0)
end

Given(/^a test performance "(.*?)" exists$/) do |perf_code|
  production = @production
  @performance = Performance.create!(
    production: production,
    performance_code: perf_code,
    performance_date: Date.today + 7.days,
    performance_time: Time.parse("19:00"),
    status: "Active"
  )

  # Create ticket class allocations
  production.ticket_classes.each do |tc|
    TicketClassAllocation.create!(
      performance: @performance,
      ticket_class: tc,
      available: true
    )
  end

  # Initialize seat assignments
  SeatAssignment.available_seat_assignments(@performance)
end

Given(/^the performance "(.*?)" has (\d+) held seats without orders$/) do |perf_code, count|
  performance = Performance.find_by_performance_code(perf_code)
  seats = performance.seat_assignments.where(status: SeatAssignment::AVAILABLE).take(count.to_i)
  seats.each do |sa|
    sa.update!(status: SeatAssignment::TEMPORARY, order_uuid: nil)
  end
end

Given(/^the performance "(.*?)" has (\d+) held seats with a valid HOLD order$/) do |perf_code, count|
  performance = Performance.find_by_performance_code(perf_code)

  # Create an address for the order
  address = Address.create!(
    full_name: "Test Customer",
    email: "test#{Time.now.to_i}@example.com",
    street: "123 Main St",
    city: "Chicago",
    state: "IL",
    zipcode: "60601"
  )

  # Get or create cash payment type
  payment_type = CashPaymentType.find_or_create_by!(display_name: "Cash")

  # Create an order with HOLD status (use validate: false to bypass seat-count validation in test setup)
  ticket_class = performance.ticket_class_allocations.first.ticket_class
  @test_order = TicketOrder.new(
    status: Order::HOLD,
    performance: performance,
    address: address,
    payment_type: payment_type
  )
  @test_order.ticket_line_items.build(
    ticket_class: ticket_class,
    ticket_count: count.to_i
  )
  @test_order.save!(validate: false)

  # Assign seats using the persisted order uuid
  seats = performance.seat_assignments.where(status: SeatAssignment::AVAILABLE).take(count.to_i)
  seats.each do |sa|
    sa.update!(status: SeatAssignment::TEMPORARY, order_uuid: @test_order.uuid)
  end
end

Given(/^the performance "(.*?)" has (\d+) assigned seat(?:s)?$/) do |perf_code, count|
  performance = Performance.find_by_performance_code(perf_code)
  seats = performance.seat_assignments.where(status: SeatAssignment::AVAILABLE).take(count.to_i)
  seats.each do |sa|
    sa.update!(status: SeatAssignment::ASSIGNED, order_uuid: SecureRandom.uuid)
  end
end

When(/^I follow "([^"]*)" and confirm$/) do |link_text|
  accept_confirm do
    click_link link_text
  end
end

# Datatable-specific steps for the new button location

Then(/^I should see "(.*?)" in the datatable for performance "(.*?)"$/) do |link_text, perf_code|
  performance = Performance.find_by_performance_code(perf_code)
  expect(page).to have_css("tr[id='#{performance.id}']", wait: 15)
  within("tr[id='#{performance.id}']") do
    expect(page).to have_link(link_text)
  end
end

Then(/^I should not see "(.*?)" in the datatable for performance "(.*?)"$/) do |link_text, perf_code|
  performance = Performance.find_by_performance_code(perf_code)
  expect(page).to have_css("tr[id='#{performance.id}']", wait: 15)
  within("tr[id='#{performance.id}']") do
    expect(page).not_to have_link(link_text)
  end
end

When(/^I follow "(.*?)" in the datatable for performance "(.*?)" and confirm$/) do |link_text, perf_code|
  performance = Performance.find_by_performance_code(perf_code)
  expect(page).to have_css("tr[id='#{performance.id}']", wait: 15)
  within("tr[id='#{performance.id}']") do
    accept_confirm do
      click_link link_text
    end
  end
end

# Step for creating a general admission production

Given(/^a general admission production "(.*?)" exists$/) do |production_name|
  theater = Theater.first || Theater.create!(
    name: "Test Theater",
    url: "http://test.example.com",
    theater_class: Theater::THEATER_CLASSES.first,
    status: Theater::THEATER_STATUSES.first
  )
  venue = Venue.find_or_create_by!(name: "Main Venue") do |v|
    v.ordinal_sort = 1
  end

  # Create production WITHOUT a seat map (general admission)
  @ga_production = Production.create!(
    name: production_name,
    production_code: "GA01",
    status: Production::PRODUCTION_STATUSES.first,
    season: Date.today.year,
    theater: theater,
    venue: venue,
    seat_map: nil, # No seat map = general admission
    opening_at: Date.today,
    closing_at: Date.today + 30.days,
    press_opening_at: Date.today,
    first_preview_at: Date.today,
    capacity: 100 # Manual capacity for general admission
  )

  # Create default ticket classes
  TicketClass.create!(production: @ga_production, class_code: "ADULT", class_name: "Adult", ticket_price: 25.00,
                      ticket_type: 'Fixed', ticketing_fee: 0.0)
  TicketClass.create!(production: @ga_production, class_code: "SENIOR", class_name: "Senior", ticket_price: 20.00,
                      ticket_type: 'Fixed', ticketing_fee: 0.0)
end

Given(/^a performance "(.*?)" exists for production "(.*?)"$/) do |perf_code, production_name|
  production = Production.find_by_name(production_name) || @ga_production
  @performance = Performance.create!(
    production: production,
    performance_code: perf_code,
    performance_date: Date.today + 8.days,
    performance_time: Time.parse("20:00"),
    status: "Active"
  )

  # Create ticket class allocations
  production.ticket_classes.each do |tc|
    TicketClassAllocation.create!(
      performance: @performance,
      ticket_class: tc,
      available: true
    )
  end

  # Initialize seat assignments only for reserved seating
  if production.has_reserved_seating?
    SeatAssignment.available_seat_assignments(@performance)
  end
end

Then(/^the performance "(.*?)" should have (\d+) held seats without orders$/) do |perf_code, count|
  performance = Performance.find_by_performance_code(perf_code)
  actual_count = performance.seat_assignments
                            .where(status: SeatAssignment::TEMPORARY)
                            .where("order_uuid is null OR NOT EXISTS (SELECT * FROM orders WHERE uuid = seat_assignments.order_uuid AND status IN (?))", Order::HOLDING_SEAT_STATUSES)
                            .count
  expect(actual_count).to eq(count.to_i)
end

Then(/^the performance "(.*?)" should have (\d+) held seats with valid orders$/) do |perf_code, count|
  performance = Performance.find_by_performance_code(perf_code)
  actual_count = performance.seat_assignments
                            .joins("INNER JOIN orders ON seat_assignments.order_uuid = orders.uuid")
                            .where(status: SeatAssignment::TEMPORARY)
                            .where("orders.status IN (?)", Order::HOLDING_SEAT_STATUSES)
                            .count
  expect(actual_count).to eq(count.to_i)
end

Then(/^the performance "(.*?)" should have (\d+) assigned seat(?:s)?$/) do |perf_code, count|
  performance = Performance.find_by_performance_code(perf_code)
  actual_count = performance.seat_assignments.where(status: SeatAssignment::ASSIGNED).count
  expect(actual_count).to eq(count.to_i)
end
