# Admin page navigation shortcuts

Given('I visit the new admin ticket order page') do
  # Set admin interface flag
  @using_admin_interface = true

  # Click the "New Ticket Order" link which opens a modal dialog
  click_link 'New Ticket Order'

  # Fill in the production code and submit the form
  fill_in 'production_code', with: Production.first.production_code
  page.execute_script("document.getElementById('new_production_id').value='#{Production.first.id}'")
  page.execute_script("document.getElementById('production-form').submit()")
end

Given('I visit the admin flex pass offer page') do
  click_link 'Passes'
  click_link 'Flex Pass Offers'
end

Given('I wait {int} seconds') do |int|
  sleep(int)
end

Then('the {string} tab should be selected') do |tab_label|
  expect(page).to have_css('#offer-status-tabs .tabs-title.is-active a', text: tab_label)
end

def enter_base_production(code, capacity = 99)
  fill_in 'Production code', with: code
  fill_in 'production_name', with: "Production #{code}"
  fill_in 'Capacity', with: capacity
  fill_in 'Season', with: Date.today.year
  fill_in 'production_opening_at', with: Date.today.to_s
  fill_in 'production_closing_at', with: Date.today.to_s

  select 'Space 1', from: 'Venue'
end

Given(/^I enter a production with code "(.*?)" and [|a ] capacity of "(.*?)"$/) do |code, capacity|
  enter_base_production(code, capacity)
end

Given(/^I enter a complete production with code "(.*?)"$/) do |code|
  enter_base_production(code)
  fill_in 'Credit lines', with: 'by Willard Shakepare'
  fill_in 'production_first_preview_at', with: "#{Date.today.year}-01-01"
  fill_in 'production_press_opening_at', with: "#{Date.today.year}-01-01"
  fill_in 'production_opening_at', with: "#{Date.today.year}-01-01"
  fill_in 'production_closing_at', with: "#{Date.today.year}-01-01"
  fill_in 'Show description', with: '<h1>Hello</h1>'
  fill_in 'Capacity', with: '300'
  fill_in 'Additional information link', with: 'http://google.com'
  select 'Active', from: 'Status'
end

Given(/^I enter a special offer with code "(.*?)" for (\d+)% off$/) do |code, percent|
  fill_in 'percent_off_special_offer_code', with: code
  fill_in 'percent_off_special_offer_amount', with: percent
end

Given(/^I enter a buy (\d+) get (\d+) special offer with code "(.*?)"$/) do |buy, get, code|
  fill_in 'buy_x_get_y_special_offer_code', with: code
  fill_in 'buy_x_get_y_special_offer_buy_quantity', with: buy
  fill_in 'buy_x_get_y_special_offer_get_quantity', with: get
end

Given(/^I enter a custom label "(.*?)"$/) do |label|
  fill_in 'production_custom_label', with: label
end

When(/^all production status values are presented$/) do
  Production::PRODUCTION_STATUSES.each { |status| select status, from: 'Status' }
end

When(/^I enter a theater called "([^"]*)"$/) do |name|
  fill_in 'theater_name', with: name
  select Theater::THEATER_CLASSES.first, from: 'Theater class'
end

When(/^I enter performance code "([^"]*)"$/) do |perf_code|
  fill_in 'ticket_order_performance_code', with: perf_code
  page.execute_script "$('#performance_id').val('#{Performance.find_by(performance_code: perf_code).id}')"
end

When(/^I enter a membership offer "(.*?)"$/) do |offer_name|
  fill_in 'Name', with: offer_name
  fill_in 'Price ID', with: 'TESTREMOTE'
  # fill_in "membership_offer_recurring_cost", :with=>"10.00"  What is equivalent when we do test structures?
  fill_in 'Tickets per performance', with: '1'
  select 'PASS', from: 'Use ticket class code'
  select 'PASSFRIEND', from: 'Use member friend code'
end

Given(/^I add a note$/) do
  click_link('Add note')
end

Given(/^I edit the note to read "(.*?)"$/) do |new_note|
  fill_in 'notes', with: new_note
end

Given(/^the performance "(.*?)" has a ticket class code "(.*?)"$/) do |perf_code, ticket_class_code|
  @performance = Performance.find_by_performance_code(perf_code)
  @performance.ticket_class_allocations << FactoryBot.create(:ticket_class_allocation, available: true,
                                                                                       ticket_class: TicketClass.find_by_class_code(ticket_class_code))
  @performance.save!
end

# Delete the below
# Transform /^the (\d+)(?:st|nd|rd|th) address tag$/ do |num|
#  "ul.address_tags li:nth-child(#{num})"
# end

# Transform /^the first address tag label$/ do
#  "$(\"#address_tags input\")[0]"
# end

Given(/^I add a tag "(.*?)" to the first address tag label$/) do |label|
  click_link('Add a tag')

  fill_in '#address_tags input:nth-of-type(1)', with: label
end
