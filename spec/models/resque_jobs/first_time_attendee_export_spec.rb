require 'rails_helper'

RSpec.describe FirstTimeAttendeeExport, type: :model do
  let(:reporting_user_id) { 42 }
  let(:theater_ids) { [1, 2] }

  # class_double('FirstTimeAttendeeReport').as_stubbed_const stands in for the
  # report class regardless of load order: it verifies against the real
  # constant when it's already loaded, and defines a stand-in otherwise, so
  # this spec passes whether or not FirstTimeAttendeeReport has landed yet.
  let(:report_class) { class_double('FirstTimeAttendeeReport').as_stubbed_const }

  it 'coerces a Resque-serialized string date and forwards it to the report' do
    report = instance_double('FirstTimeAttendeeReport')
    allow(report_class).to receive(:new)
      .with(Date.new(2026, 7, 1), reporting_user_id, theater_ids: theater_ids).and_return(report)
    expect(described_class).to receive(:send_report).with(report)

    described_class.perform('2026-07-01', reporting_user_id, theater_ids)
  end

  it 'defaults theater_ids to an empty array when omitted' do
    report = instance_double('FirstTimeAttendeeReport')
    allow(report_class).to receive(:new)
      .with(Date.new(2026, 7, 1), reporting_user_id, theater_ids: []).and_return(report)
    expect(described_class).to receive(:send_report).with(report)

    described_class.perform('2026-07-01', reporting_user_id)
  end
end
