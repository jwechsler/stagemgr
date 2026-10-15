# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lgl::GiftPayload do
  let(:order) { FactoryBot.create(:donation_order_for_one_thousand_dollars) }
  let(:paid_at) { Time.zone.local(2026, 3, 15, 12, 0, 0) }
  let(:ids) { { campaign_id: 11, appeal_id: 22, event_id: 33 } }

  # A charged card payment carries its gateway confirmation code.
  let(:card_attributes) { { confirmation_code: 'ch_test123', card_type: 'Visa', card_last_four: '4242' } }

  def pay(factory, amount, processed_on: paid_at)
    extra = factory == :credit_card_payment ? card_attributes : {}
    FactoryBot.create(factory, order: order, amount: amount, processed_on: processed_on, **extra)
  end

  describe '.external_id' do
    it 'prefixes the order id' do
      expect(described_class.external_id(order)).to eq("stagemgr-#{order.id}")
    end
  end

  describe '.for_create' do
    it 'builds the gift for a credit card donation dated by its payment' do
      pay(:credit_card_payment, 1000.0)
      expect(described_class.for_create(order.reload, **ids)).to eq(
        gift_type_id: 1, gift_type_name: 'Gift', external_id: "stagemgr-#{order.id}",
        campaign_id: 11, appeal_id: 22, event_id: 33,
        received_amount: 1000.0, deductible_amount: 1000.0, deposited_amount: 1000.0,
        received_date: '2026-03-15', deposit_date: '2026-03-15',
        payment_type_name: 'Credit Card', note: "Stagemgr donation order ##{order.id}"
      )
    end

    it 'uses the earliest tender as the received date' do
      pay(:cash_payment, 500.0, processed_on: paid_at + 2.days)
      pay(:cash_payment, 500.0)
      expect(described_class.for_create(order.reload, **ids)).to include(received_date: '2026-03-15')
    end

    it 'maps cash payments' do
      pay(:cash_payment, 1000.0)
      expect(described_class.for_create(order.reload, **ids)).to include(payment_type_name: 'Cash')
    end

    it 'maps check payments' do
      CheckPayment.create!(order: order, amount: 1000.0, processed_on: paid_at,
                           payment_type: FactoryBot.create(:check_payment_type))
      expect(described_class.for_create(order.reload, **ids)).to include(payment_type_name: 'Check')
    end

    it 'omits the payment type for an unmapped payment class and dates by the order' do
      pay(:external_payment, 1000.0)
      payload = described_class.for_create(order.reload, **ids)
      expect(payload).not_to have_key(:payment_type_name)
      expect(payload[:received_date]).to eq(order.updated_at.to_date.iso8601)
    end

    it 'leaves out nil campaign, appeal and event ids' do
      pay(:credit_card_payment, 1000.0)
      payload = described_class.for_create(order.reload, campaign_id: nil, appeal_id: nil, event_id: nil)
      expect(payload.keys).not_to include(:campaign_id, :appeal_id, :event_id)
    end
  end

  describe '.refund_note' do
    before do
      pay(:credit_card_payment, 1000.0)
      pay(:credit_card_payment, -1000.0, processed_on: Time.zone.local(2026, 4, 2, 12, 0, 0))
      order.reload
    end

    it 'appends the refund date to an existing note' do
      expect(described_class.refund_note(order, 'Thanks!')).to eq(
        gift_type_id: 1, gift_type_name: 'Gift', note: "Thanks!\nRefunded in Stagemgr on 2026-04-02"
      )
    end

    it 'starts a fresh note when there is none' do
      expect(described_class.refund_note(order, nil)[:note]).to eq('Refunded in Stagemgr on 2026-04-02')
    end

    it 'dates the note today when no refund payment exists' do
      order.payments.select { |payment| payment.amount.negative? }.each(&:destroy!)
      expect(described_class.refund_note(order.reload, '')[:note])
        .to eq("Refunded in Stagemgr on #{Date.current.iso8601}")
    end
  end

  describe '.refund_noted?' do
    it 'detects the refund note' do
      expect(described_class.refund_noted?("Thanks!\nRefunded in Stagemgr on 2026-04-02")).to be(true)
      expect(described_class.refund_noted?('Thanks!')).to be(false)
      expect(described_class.refund_noted?(nil)).to be(false)
    end
  end
end
