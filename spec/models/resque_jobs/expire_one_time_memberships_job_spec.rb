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

  context 'when one membership cannot be saved' do
    let!(:broken) { one_time(Date.current - 3) }
    let!(:healthy) { one_time(Date.current - 1) }

    before do
      allow(Rails.logger).to receive(:error)
      allow(Rails.logger).to receive(:info)
      # A legacy row that fails validation, wherever find_each meets it.
      allow_any_instance_of(Membership).to receive(:expire!).and_wrap_original do |original, *args|
        if original.receiver.id == broken.id
          raise ActiveRecord::RecordInvalid, original.receiver
        end

        original.call(*args)
      end
    end

    it 'logs it, expires the rest, and reports both counts' do
      expect(described_class.perform).to eq(expired: 1, failed: 1)

      expect(healthy.reload.status).to eq(Membership::EXPIRED)
      expect(broken.reload).to have_attributes(status: Membership::ACTIVE, ended_at: nil)
      expect(Rails.logger).to have_received(:error)
        .with(/could not expire membership #{broken.id} \(expires_on #{(Date.current - 3).iso8601}\): ActiveRecord::RecordInvalid/)
      expect(Rails.logger).to have_received(:info).with(/expired 1 one-time memberships, 1 failed/)
    end

    it 'emails the box office the memberships it could not expire' do
      expect { described_class.perform }.to change { ActionMailer::Base.deliveries.size }.by(1)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([Rails.configuration.x.email_address['box_office']])
      expect(mail.subject).to eq('1 membership could not be expired')
      expect(mail.body.encoded).to include(broken.member_code, "/admin/memberships/#{broken.id}", 'RecordInvalid')
      expect(mail.body.encoded).not_to include("/admin/memberships/#{healthy.id}")
    end

    it 'still finishes the run when the alert cannot be sent' do
      allow(NotificationMailer).to receive(:membership_expiry_failed_alert).and_raise(Net::SMTPFatalError, 'mail down')

      expect(described_class.perform).to eq(expired: 1, failed: 1)
      expect(Rails.logger).to have_received(:error).with(/could not email the box office about 1 failed expirations.*mail down/)
    end

    it 'retries the failed membership on the next run once it can be saved' do
      described_class.perform
      allow_any_instance_of(Membership).to receive(:expire!).and_call_original

      expect(described_class.perform).to eq(expired: 1, failed: 0)
      expect(broken.reload.status).to eq(Membership::EXPIRED)
    end
  end

  it 'sends no alert when every membership expires' do
    one_time(Date.current - 1)

    expect { described_class.perform }.not_to(change { ActionMailer::Base.deliveries.size })
  end

  it 'records its run' do
    described_class.perform
    described_class.after_perform_record_last_run

    expect(JobMetadata.last_run('ExpireOneTimeMembershipsJob')).to be_within(1.minute).of(Time.current)
  end
end
