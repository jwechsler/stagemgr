require 'rails_helper'
require 'csv' # the helper relies on something else having loaded it

# Literal strings on purpose: these pin how report cells and CSV exports print
# dates and times, so a Rails bump that changes the formats fails here.
RSpec.describe Admin::ReportsHelper do
  let(:evening) { Time.zone.local(2026, 9, 28, 19, 30) }

  describe '.tidy_output' do
    it 'prints a time as the hour and minute' do
      expect(described_class.tidy_output(evening)).to eq(' 7:30PM')
    end

    it 'passes a date through unchanged' do
      expect(described_class.tidy_output(Date.new(2026, 9, 28))).to eq(Date.new(2026, 9, 28))
    end
  end

  describe '.save_report_as_csv' do
    it 'writes times as hour and minute and dates as ISO dates' do
      path = Rails.root.join('tmp', "reports_helper_spec_#{Process.pid}.csv").to_s
      rows = [{ performance_date: Date.new(2026, 9, 28), performance_time: evening }]

      described_class.save_report_as_csv(path, %i[performance_date performance_time], rows)

      expect(File.read(path)).to eq("performance_date,performance_time\n2026-09-28, 7:30PM\n")
    ensure
      FileUtils.rm_f(path)
    end
  end
end
