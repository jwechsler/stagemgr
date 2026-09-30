# Latch for seat reserve/release requests (features/seat_double_click.feature).
# Wraps $.post -- what seat_assignment.js and reseating.js call -- so each
# reserve/release is recorded and held until a step lets it through, and
# returns a jQuery Deferred promise so .done/.fail/.always chaining still works.
# window.alert is replaced with a recorder: a real alert blocks WebDriver.
SEAT_LATCH_JS = <<~JS.freeze
  (function() {
    var latch = { held: [], alerts: [] };
    var realPost = $.post;
    window.alert = function(message) { latch.alerts.push(String(message)); };
    $.post = function(url, data, success) {
      if (!/\\/(reserve|release)\\.json/.test(String(url))) { return realPost.apply(this, arguments); }
      var deferred = $.Deferred();
      if (typeof success === 'function') { deferred.done(success); }
      latch.held.push({ url: url, data: data, deferred: deferred });
      return deferred.promise();
    };
    latch.release = function(index) {
      var request = latch.held.splice(index, 1)[0];
      realPost(request.url, request.data)
        .done(function(response, status, xhr) { request.deferred.resolve(response, status, xhr); })
        .fail(function(xhr, status, error) { request.deferred.reject(xhr, status, error); });
    };
    latch.reject = function(index, httpStatus, message) {
      var request = latch.held.splice(index, 1)[0];
      var xhr = { status: httpStatus, responseText: JSON.stringify({ status: 'error', message: message }) };
      request.deferred.reject(xhr, 'error', 'rejected');
    };
    window.__seatLatch = latch;
  })();
JS

# Polls (like the existing seat-map steps) until the block is true or
# Capybara's wait time runs out; the caller's expectation then reports.
def wait_for_condition
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
  sleep 0.05 until yield || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
end

def open_seat_ids
  @open_seat_ids ||= all('#seatingmap circle.available[data-assignment-id]').map { |c| c['data-assignment-id'].to_i }
end

def open_seat(number)
  find("#seatingmap circle[data-assignment-id='#{open_seat_ids.fetch(number - 1)}']")
end

def seat_rows(number)
  all("#ticket-display .ticket_line_item[data-seat-assignment-id='#{open_seat_ids.fetch(number - 1)}']")
end

def held_seat_requests
  page.evaluate_script('window.__seatLatch.held.length')
end

# Clicks the modal's class button by script: it also reaches a button whose
# modal has closed, as a repeat click during the close does.
def click_class_button(class_name)
  page.execute_script(<<~JS, class_name)
    var className = arguments[0];
    var rows = $('#ticket-selector > .grid-x').filter(function() { return $(this).text().indexOf(className) !== -1; });
    rows.find('.ticket-class-select-button')[0].click();
  JS
end

When(/^I hold seat requests$/) do
  expect(page).to have_css('#seatingmap circle.available[data-assignment-id]')
  open_seat_ids
  page.execute_script(SEAT_LATCH_JS)
end

When(/^I pick "(.*?)" for open seat (\d+)$/) do |class_name, number|
  @picked_seat_id = open_seat_ids.fetch(number.to_i - 1)
  open_seat(number.to_i).click
  within('#ticket-modal') { find('#ticket-selector .grid-x', text: class_name).find_link('Select').click }
  expect(page).to have_no_css('#ticket-modal', visible: true)
end

When(/^I click open seat (\d+) and its "(.*?)" button again$/) do |number, class_name|
  open_seat(number.to_i).click
  click_class_button(class_name)
end

Then(/^(\d+) seat requests? (?:is|are) held$/) do |count|
  wait_for_condition { held_seat_requests == count.to_i }
  expect(held_seat_requests).to eq(count.to_i)
end

Then(/^open seat (\d+) is( not)? pending$/) do |number, negated|
  selector = "#seatingmap circle.seat-pending[data-assignment-id='#{open_seat_ids.fetch(number.to_i - 1)}']"
  negated ? expect(page).to(have_no_css(selector)) : expect(page).to(have_css(selector))
end

When(/^I let held request (\d+) through$/) do |position|
  page.execute_script("window.__seatLatch.release(#{position.to_i - 1})")
end

When(/^I reject held request (\d+) with status (\d+) and message "(.*?)"$/) do |position, status, message|
  page.execute_script('window.__seatLatch.reject(arguments[0], arguments[1], arguments[2])',
                      position.to_i - 1, status.to_i, message)
end

Then(/^open seat (\d+) has (one|no) ticket rows?$/) do |number, how_many|
  expected = how_many == 'one' ? 1 : 0
  wait_for_condition { seat_rows(number.to_i).size == expected }
  expect(seat_rows(number.to_i).size).to eq(expected)
end

Then(/^the ticket rows name open seats (\d+) and (\d+) once each$/) do |first, second|
  [first, second].map(&:to_i).each do |number|
    location = open_seat(number)['data-location']
    rows = seat_rows(number)
    expect(rows.size).to eq(1)
    expect(rows.first.text).to start_with("#{location} / ")
    expect(find('#seatlocations').text.split(', ').count(location)).to eq(1)
  end
end

Then(/^an alert said "(.*?)"$/) do |message|
  wait_for_condition { page.evaluate_script('window.__seatLatch.alerts').include?(message) }
  expect(page.evaluate_script('window.__seatLatch.alerts')).to include(message)
end

Then(/^open seat (\d+) is still open$/) do |number|
  expect(open_seat(number.to_i)[:class].split).to include('available')
end
