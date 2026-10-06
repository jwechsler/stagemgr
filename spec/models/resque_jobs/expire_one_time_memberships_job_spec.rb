require 'rails_helper'

RSpec.describe ExpireOneTimeMembershipsJob do
  def one_time(expires_on, status: Membership::ACTIVE)
    FactoryBot.create(:membership, profile_id: nil, status: status, expires_on: expires_on)
  end

  it 'expires Active memberships past their expiry date, ending them on that date' do
    past = one_time(Date.current - 1)

    described_class.perform

    expect(past.reload).to have_attributes(status: Membership::EXPIRED, ended_at: Date.current - 1)
  end

  it 'leaves a membership expiring today alone, since today is still covered' do
    today = one_time(Date.current)

    described_class.perform

    expect(today.reload.status).to eq(Membership::ACTIVE)
  end

  it 'leaves memberships that are not Active, and subscriptions, alone' do
    canceled = one_time(Date.current - 5, status: Membership::CANCELED)
    subscription = FactoryBot.create(:membership)

    described_class.perform

    expect(canceled.reload.status).to eq(Membership::CANCELED)
    expect(subscription.reload.status).to eq(Membership::ACTIVE)
  end

  it 'records its run' do
    described_class.perform
    described_class.after_perform_record_last_run

    expect(JobMetadata.last_run('ExpireOneTimeMembershipsJob')).to be_within(1.minute).of(Time.current)
  end
end
