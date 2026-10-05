require 'rails_helper'

# Stripe::Price.retrieve is stubbed; no network calls are made.
RSpec.describe SyncMembershipOfferBillingPeriodJob do
  let(:offer) { FactoryBot.create(:membership_offer, price_id: 'price_123') }
  let(:stripe_gateway) { StripeGateway.new(login: 'sk_test_fakekeyfortesting') }

  def stripe_price(recurring)
    double('Stripe::Price', recurring: recurring && double('recurring', **recurring))
  end

  before do
    allow(Resque).to receive(:enqueue)
    allow(PaymentProcessing).to receive(:gateway).and_return(stripe_gateway)
  end

  {
    'a monthly price' => [{ interval: 'month', interval_count: 1 }, 'month', 1],
    'a yearly price' => [{ interval: 'year', interval_count: 1 }, 'year', 1],
    'a two-year price' => [{ interval: 'year', interval_count: 2 }, 'year', 2],
    'a one-time price' => [nil, 'one_time', nil]
  }.each do |description, (recurring, interval, count)|
    it "stores the period of #{description}" do
      allow(Stripe::Price).to receive(:retrieve).with('price_123').and_return(stripe_price(recurring))

      described_class.perform(offer.id)

      expect(offer.reload).to have_attributes(billing_interval: interval, billing_interval_count: count)
      expect(offer.billing_period_synced_at).to be_present
    end
  end

  it 'does not re-enqueue itself when it stores the period' do
    offer
    allow(Stripe::Price).to receive(:retrieve).and_return(stripe_price(interval: 'month', interval_count: 1))

    expect(Resque).not_to receive(:enqueue)

    described_class.perform(offer.id)
  end

  it 'leaves the offer unsynced and logs when Stripe does not know the price' do
    allow(Stripe::Price).to receive(:retrieve).and_raise(Stripe::InvalidRequestError.new('No such price', 'id'))
    allow(Rails.logger).to receive(:warn)

    described_class.perform(offer.id)

    expect(offer.reload.billing_interval).to be_nil
    expect(Rails.logger).to have_received(:warn).with(/price_123 not found/)
  end

  it 'raises other errors so the job can be retried' do
    allow(Stripe::Price).to receive(:retrieve).and_raise(Stripe::APIConnectionError.new('timeout'))

    expect { described_class.perform(offer.id) }.to raise_error(Stripe::APIConnectionError)
  end

  it 'does nothing for a vanished offer id' do
    expect(Stripe::Price).not_to receive(:retrieve)

    expect { described_class.perform(-1) }.not_to raise_error
  end

  it 'does nothing for an offer without a price_id' do
    timed = FactoryBot.create(:membership_offer, :timed)

    expect(Stripe::Price).not_to receive(:retrieve)

    described_class.perform(timed.id)
  end
end
