# Lets a @javascript scenario's in-flight page requests finish before the
# database is truncated. Pages such as an order's history load their table
# with an AJAX request after the page renders; if the scenario's last step
# passes first, truncation can run under that request, which then fails on
# half-deleted records and Capybara reports it as the scenario's error.
module SettleBrowserRequests
  PENDING_JQUERY_REQUESTS_JS = "typeof jQuery === 'undefined' ? 0 : jQuery.active".freeze

  def settle_browser_requests
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    sleep 0.05 until no_pending_requests? || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
  end

  private

  # A page that is gone, mid-navigation or showing an alert has nothing
  # left to wait for.
  def no_pending_requests?
    page.evaluate_script(PENDING_JQUERY_REQUESTS_JS).to_i.zero?
  rescue StandardError
    true
  end
end

World(SettleBrowserRequests)
