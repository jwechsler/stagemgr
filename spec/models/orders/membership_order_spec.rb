require 'rails_helper'

RSpec.describe MembershipOrder do
  it 'should automatically notify management when the embedded recurring profile is suspended' do
    recurring_order = FactoryBot.create(:membership_order)
    pending_tasks = recurring_order.tasks.count
    profile = recurring_order.recurring_profile
    expect(profile.status).to eq(RecurringProfile::ACTIVE)
    profile.status = RecurringProfile::SUSPENDED
    profile.save
    recurring_order.reload
    expect(profile.recurring_order.tasks.count).to eq(pending_tasks + 1)
    expect(profile.recurring_order.tasks.last).to be_kind_of(NotificationTask)
  end

  it 'refuses to purchase a timed (library pass) offer and never touches Stripe' do
    address = FactoryBot.create(:address)
    offer = FactoryBot.create(:membership_offer, :timed)
    order = MembershipOrder.new(address: address,
                                payment_type: FactoryBot.create(:credit_card_payment_type))
    order.membership_line_item = FactoryBot.build(:membership_line_item, membership_offer: offer,
                                                                         address: address, order: order)

    expect(PaymentProcessing).not_to receive(:create_subscription)
    expect { order.transition_processing_to_processed! }
      .to raise_error(/issued by the box office/)
  end

  describe 'buying a one-time (gift) offer' do
    let(:address) { FactoryBot.create(:address) }
    let(:offer) do
      FactoryBot.create(:membership_offer, price_id: 'price_once', max_cycles_if_gift: 6).tap do |o|
        o.update_columns(billing_interval: MembershipOffer::ONE_TIME, billing_interval_count: nil,
                         billing_period_synced_at: Time.current)
      end
    end

    def one_time_order(**attributes)
      membership = FactoryBot.create(:membership, address: address, membership_offer: offer,
                                                  profile_id: nil, status: Membership::PENDING)
      order = MembershipOrder.new(address: address, payment_type: FactoryBot.create(:credit_card_payment_type),
                                  status: Order::NEW, special_request: Membership::ON_AISLE, **attributes)
      order.membership_line_item = FactoryBot.build(:membership_line_item, membership_offer: offer,
                                                                           membership: membership,
                                                                           address: address, order: order)
      order.credit_card_number = '4111111111111111'
      order.credit_card_type = 'bogus'
      order.credit_card_expiration_month = '12'
      order.credit_card_expiration_year = (Date.current.year + 1).to_s
      order.credit_card_verification_number = '999'
      order
    end

    before do
      allow(PaymentProcessing).to receive(:create_subscription)
      allow(PaymentProcessing).to receive(:charge_one_time).and_call_original
      allow(PaymentProcessing).to receive(:refund_one_time)
    end

    it 'charges once, never subscribes, and activates the membership for its term' do
      order = one_time_order
      order.transition_to!(Order::PROCESSED)

      membership = order.reload.membership
      expect(PaymentProcessing).not_to have_received(:create_subscription)
      expect(PaymentProcessing).to have_received(:charge_one_time).once
      expect(order).to be_processed
      expect(membership).to have_attributes(status: Membership::ACTIVE, profile_id: nil,
                                            start_date: Date.current, expires_on: (Date.current >> 6) - 1,
                                            preferred_seating: Membership::ON_AISLE)
    end

    it 'records one RecurringPayment keyed by the invoice id' do
      order = one_time_order
      order.transition_to!(Order::PROCESSED)

      payments = RecurringPayment.where(type: 'RecurringPayment', order_id: order.id)
      expect(payments.count).to eq(1)
      expect(payments.first.transaction_id).to start_with('in_TEST')
      expect(payments.first.amount).to eq(PaymentProcessing::BogusGateway::BOGUS_ONE_TIME_CENTS / 100.0)
    end

    it 'starts the term on a later gift date' do
      gift_date = Date.current + 20
      order = one_time_order(gift: true, gift_date: gift_date, recipient_name: 'Gift Recipient',
                             recipient_email: 'recipient@example.com')
      order.transition_to!(Order::PROCESSED)

      expect(order.reload.membership).to have_attributes(start_date: gift_date, expires_on: (gift_date >> 6) - 1)
    end

    it 'syncs an unsynced offer inline so it is not sent to Subscription.create' do
      offer.update_columns(billing_interval: nil, billing_period_synced_at: nil)
      allow(PaymentProcessing).to receive(:price_billing_period)
        .with('price_once').and_return(interval: MembershipOffer::ONE_TIME, interval_count: nil)
      order = one_time_order
      order.transition_to!(Order::PROCESSED)

      expect(offer.reload).to be_one_time_payment
      expect(PaymentProcessing).not_to have_received(:create_subscription)
      expect(order.reload.membership.expires_on).to eq((Date.current >> 6) - 1)
    end

    it 'reports a failed charge without mentioning a payment plan' do
      allow(PaymentProcessing).to receive(:charge_one_time).and_raise(Stripe::CardError.new('Your card was declined.', nil))
      order = one_time_order

      expect { order.transition_to!(Order::PROCESSED) }
        .to raise_error(/setting up your account for the #{offer.name}\. Your card was declined/)
      expect(order.membership.reload.status).to eq(Membership::PENDING)
      expect(PaymentProcessing).not_to have_received(:refund_one_time)
    end

    # A paid invoice is not a CreditCardPayment, so the base reversal cannot
    # see it; MembershipOrder refunds it before the rollback surfaces.
    context 'when something fails after the invoice is paid' do
      let(:invoice) { PaymentProcessing::BogusGateway::BogusInvoice.new(id: 'in_PAID', amount_paid: 9900) }

      before do
        allow(PaymentProcessing).to receive(:charge_one_time).and_return(invoice)
        allow(Rails.logger).to receive(:error)
      end

      it 'refunds the invoice when membership.save! raises, as an app refund' do
        order = one_time_order
        allow(order.membership).to receive(:save!).and_raise(ActiveRecord::RecordInvalid)

        expect { order.transition_to!(Order::PROCESSED) }.to raise_error(/setting up your account/)
        expect(PaymentProcessing).to have_received(:refund_one_time)
          .with('in_PAID', hash_including(source: CreditCardPayment::REFUND_SOURCE))
        expect(Rails.logger).to have_received(:error).with(/after invoice in_PAID \(\$99\.00\); refunding it/)
        expect(RecurringPayment.where(type: 'RecurringPayment', transaction_id: 'in_PAID')).not_to exist
      end

      it 'refunds the invoice when the order save after the charge raises' do
        order = one_time_order
        allow(order).to receive(:set_email_confirmation).and_raise(RuntimeError, 'mailer down')

        expect { order.transition_to!(Order::PROCESSED) }.to raise_error(/mailer down/)
        expect(PaymentProcessing).to have_received(:refund_one_time).with('in_PAID', anything).once
      end

      it 'logs MANUAL REFUND NEEDED when the refund itself fails' do
        allow(PaymentProcessing).to receive(:refund_one_time).and_raise(Stripe::APIConnectionError, 'stripe unreachable')
        order = one_time_order
        allow(order.membership).to receive(:save!).and_raise(ActiveRecord::RecordInvalid)

        expect { order.transition_to!(Order::PROCESSED) }.to raise_error(/setting up your account/)
        expect(Rails.logger).to have_received(:error)
          .with(/MANUAL REFUND NEEDED for invoice in_PAID \(\$99\.00\): stripe unreachable/)
      end
    end
  end
end
