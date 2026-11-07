# Steps for app/assets/javascripts/autocomplete_defaults.js: the debounce
# delay and the replay of an identical search within the repeat window.

module AutocompleteDefaultsHelpers
  PERFORMANCE_CODE_FIELD = '#ticket_order_performance_code'.freeze

  def performance_code_field
    PERFORMANCE_CODE_FIELD
  end

  # Resource-timing entries for the performance code autocomplete URL. The
  # buffer is cleared before the first search so earlier page assets cannot
  # fill it and hide the request.
  def performance_code_autocomplete_request_count
    page.evaluate_script(<<~JS)
      performance.getEntriesByType('resource')
        .filter(function(e) { return e.name.indexOf('autocomplete_performance_performance_code') !== -1; })
        .length
    JS
  end

  # True once a completed request for exactly this term is in the buffer.
  def performance_code_autocomplete_requested_term?(term)
    page.evaluate_script(<<~JS)
      performance.getEntriesByType('resource').some(function(e) {
        return e.name.indexOf('autocomplete_performance_performance_code') !== -1 &&
          new URL(e.name).searchParams.get('term') === #{term.to_json};
      })
    JS
  end
end

World(AutocompleteDefaultsHelpers)

When('I focus the performance code field') do
  find(performance_code_field).click
  # The gem initialises the widget lazily on focus.
  expect(page).to have_css("#{performance_code_field}.ui-autocomplete-input")
end

Then('the performance code autocomplete delay should be {int}') do |delay|
  expect(page.evaluate_script("$('#{performance_code_field}').autocomplete('option', 'delay')").to_i).to eq(delay)
end

When('I search the performance code field for {string}') do |term|
  page.execute_script('performance.setResourceTimingBufferSize(1000); performance.clearResourceTimings();')
  find(performance_code_field).set(term)
end

Then('the performance code menu should list {string}') do |performance_code|
  expect(page).to have_css('ul.ui-autocomplete li', text: performance_code, visible: true)
end

When('I close the performance code menu') do
  page.execute_script("$('#{performance_code_field}').autocomplete('close')")
  expect(page).to have_no_css('ul.ui-autocomplete li', visible: true)
end

When('I repeat the performance code search for {string}') do |term|
  page.execute_script("$('#{performance_code_field}').autocomplete('search', #{term.to_json})")
end

# Selenium types the term one character at a time, so a pause longer than the
# debounce delay between keystrokes can legitimately add requests for partial
# terms, and one of those can open the menu first. Wait for the full term's
# request to complete so nothing is still in flight when the count is noted.
Then('the performance code autocomplete should have requested the server for {string}') do |term|
  page.document.synchronize do
    raise Capybara::ExpectationNotMet, "no autocomplete request for #{term}" unless performance_code_autocomplete_requested_term?(term)
  end
end

When('I note how many performance code autocomplete requests have been made') do
  @noted_performance_code_request_count = performance_code_autocomplete_request_count
end

Then('the performance code autocomplete should have made no further requests') do
  expect(performance_code_autocomplete_request_count).to eq(@noted_performance_code_request_count)
end
