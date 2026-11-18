# Steps for the graphical seat map editor (Konva canvas). The seats are drawn
# on a canvas, so there is no DOM element per seat: a seat is selected with a
# real pointer click at its computed screen position.

# Recorded map size: the editor fits this size into the stage, so seat
# coordinates below are laid out in this space.
EDITOR_MAP_WIDTH = 1200
EDITOR_MAP_HEIGHT = 900
EDITOR_SEAT_RADIUS = 30
EDITOR_SEAT_SPACING = 140

Given(/^the seat map for venue "(.*?)" is plotted$/) do |venue_name|
  seat_map = Venue.find_by!(name: venue_name).seat_maps.first
  # Attached directly with a fixed size recorded, as in "the seat map for ...
  # is plotted": SeatMap#save_image_dimensions would measure the 1x1 PNG.
  blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(SEAT_MAP_PNG), filename: 'seat-map.png',
                                                content_type: 'image/png',
                                                metadata: { identified: true, analyzed: true,
                                                            width: EDITOR_MAP_WIDTH, height: EDITOR_MAP_HEIGHT })
  ActiveStorage::Attachment.create!(name: 'base_image_map', record: seat_map, blob: blob)
  seat_map.seats.order(:seat_number).each_with_index do |seat, index|
    seat.update!(origin_x: 100 + (index * EDITOR_SEAT_SPACING), origin_y: 200,
                 width: EDITOR_SEAT_RADIUS, height: EDITOR_SEAT_RADIUS)
  end
end

When(/^the seat map editor has loaded (\d+) seats$/) do |count|
  expect(page).to have_css('#editor-status', text: "Loaded #{count} seats")
end

When(/^I click the first seat in the seat map editor$/) do
  @editor_seat = @venue.seat_maps.first.seats.order(:seat_number).first
  @editor_seat_location = @editor_seat.location
  stage = find('#seatmap-editor .konvajs-content')
  size = stage.native.size
  # The editor scales the map to fit the stage (no pan offset until the user
  # zooms or pans), so a seat's screen position is its origin times that
  # scale. Capybara click offsets are measured from the element centre.
  scale = [size.width.to_f / EDITOR_MAP_WIDTH, size.height.to_f / EDITOR_MAP_HEIGHT].min
  stage.click(x: ((@editor_seat.origin_x * scale) - (size.width / 2)).round,
              y: ((@editor_seat.origin_y * scale) - (size.height / 2)).round)
  expect(page).to have_css('#row-input:not([disabled])')
end

When(/^I enter "(.*?)" in the editor's (Row|Number) box$/) do |value, box|
  input = find("##{box.downcase}-input")
  input.set(value)
  input.send_keys(:enter)
end

Then(/^the editor should show unsaved changes$/) do
  expect(page).to have_css('#dirty-indicator', visible: :visible)
end

Then(/^the editor should not show unsaved changes$/) do
  expect(page).to have_css('#dirty-indicator', visible: :hidden)
end

Then(/^the editor status should be the error "(.*?)"$/) do |message|
  expect(page).to have_css('#editor-status.error', text: message)
end

When(/^I save the seat map editor$/) do
  click_button 'Save'
  expect(page).to have_css('#editor-status', text: /Saved \d+ change/)
end

Then(/^the clicked seat should have row "(.*?)" and number (\d+) with its location unchanged$/) do |row, number|
  @editor_seat.reload
  expect([@editor_seat.row, @editor_seat.seat_number, @editor_seat.location])
    .to eq([row, number.to_i, @editor_seat_location])
end
