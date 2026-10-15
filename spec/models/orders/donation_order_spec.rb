require 'rails_helper'

RSpec.describe 'a donation order' do
  context 'when a single donation' do
    it 'should process a one-time payment accurately' do
      @donation = FactoryBot.create(:donation_order_for_one_thousand_dollars)
      expect(@donation.status).to eq(Order::HOLD)
      expect(@donation.total_due).to eq(1000.00)
      expect(@donation.total_paid).to eq(0.0)
      @donation.payment_type = FactoryBot.create(:cash_payment_type)
      @donation.transition_to!(Order::PROCESSED)

      expect(@donation.total_paid).to eq(1000.0)
      expect(@donation.total_due).to eq(1000.00)
    end
  end

  describe 'refunding a donation replicated to LGL' do
    let(:donation) do
      FactoryBot.create(:donation_order_for_one_thousand_dollars).tap do |order|
        order.payment_type = FactoryBot.create(:cash_payment_type)
        order.transition_to!(Order::PROCESSED)
      end
    end

    before do
      allow(Lgl).to receive(:enabled?).and_return(true)
      allow(Resque).to receive(:enqueue_in)
    end

    it 'queues a refund note on its LGL gift' do
      donation.update_column(:lgl_gift_id, 7001)
      donation.refund!

      expect(Resque).to have_received(:enqueue_in)
        .with(Order::LGL_REFUND_NOTE_DELAY, LglReplicateDonationJob, donation.id, 'refund')
    end

    it 'queues nothing for a donation with no LGL gift' do
      donation.refund!

      expect(Resque).not_to have_received(:enqueue_in).with(anything, LglReplicateDonationJob, any_args)
    end

    it 'queues nothing when LGL is disabled' do
      donation.update_column(:lgl_gift_id, 7001)
      allow(Lgl).to receive(:enabled?).and_return(false)
      donation.refund!

      expect(Resque).not_to have_received(:enqueue_in).with(anything, LglReplicateDonationJob, any_args)
    end
  end
end
