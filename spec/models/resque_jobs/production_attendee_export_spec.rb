require 'rails_helper'

RSpec.describe ProductionAttendeeExport, type: :model do
  let(:reporting_user_id) { 42 }

  it 'forwards an array of production ids to the report' do
    report = instance_double(ProductionAttendeeReport)
    expect(ProductionAttendeeReport).to receive(:new)
      .with([1, 2], true, reporting_user_id).and_return(report)
    expect(described_class).to receive(:send_report).with(report)

    described_class.perform([1, 2], true, reporting_user_id)
  end

  it 'forwards a legacy scalar production id unchanged (report normalizes it)' do
    report = instance_double(ProductionAttendeeReport)
    expect(ProductionAttendeeReport).to receive(:new)
      .with(7, false, reporting_user_id).and_return(report)
    expect(described_class).to receive(:send_report).with(report)

    described_class.perform(7, false, reporting_user_id)
  end
end
