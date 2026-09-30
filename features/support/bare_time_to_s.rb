# frozen_string_literal: true

# See spec/support/bare_time_to_s_detector.rb (remove on Rails 7.1+). at_exit
# rather than AfterAll so the report prints after Cucumber's summary and can
# still turn a passing run into a failing exit status.
require Rails.root.join('spec/support/bare_time_to_s_detector')

at_exit do
  report = BareTimeToSDetector.report
  next unless report

  warn report
  exit 1 unless BareTimeToSDetector.report_only?
end
