require 'rails_helper'

RSpec.describe RefundPayment, type: :model do
  let(:order) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_credit_card) }
  let(:card_payment) { order.payments.grep(CreditCardPayment).first }
  let(:gateway) { double('gateway') }

  def build_refund(source, amount: -10.0)
    RefundPayment.new(order: source.order, source_payment: source, payment_type: source.payment_type,
                      amount: amount)
  end

  before { allow(PaymentProcessing).to receive(:gateway).and_return(gateway) }

  describe 'naming' do
    it 'appends Refund to the tender name' do
      expect(build_refund(card_payment).display_name).to eq('Credit Card Refund')
    end

    it 'has a Refund receipt description' do
      expect(build_refund(card_payment).receipt_description).to eq('Refund')
    end

    it 'cannot be cancelled' do
      expect(build_refund(card_payment).can_cancel?).to be(false)
    end
  end

  describe '#refund_cents' do
    it 'converts the absolute amount to whole cents' do
      expect(build_refund(card_payment, amount: BigDecimal('-19.99')).refund_cents).to eq(1999)
    end

    it 'rounds exactly where a float multiply would lose a cent' do
      expect(build_refund(card_payment, amount: BigDecimal('-0.29')).refund_cents).to eq(29)
    end
  end

  describe 'validations' do
    it 'is valid against a credit card payment with a negative amount' do
      expect(build_refund(card_payment)).to be_valid
    end

    it 'is invalid when the amount is not negative' do
      expect(build_refund(card_payment, amount: 10.0)).not_to be_valid
    end

    it 'requires a payment type' do
      refund = RefundPayment.new(order: order, source_payment: card_payment, amount: -1.0)
      expect(refund).not_to be_valid
      expect(refund.errors[:payment_type]).to be_present
    end

    it 'reports under the refunded payment\'s type' do
      refund = build_refund(card_payment)
      expect(refund.payment_type).to eq(card_payment.payment_type)
      expect(refund.report_as_sales_collected?).to eq(card_payment.report_as_sales_collected?)
    end

    it 'is invalid without a source payment' do
      refund = RefundPayment.new(order: order, payment_type: card_payment.payment_type, amount: -1.0)
      expect(refund).not_to be_valid
    end

    it 'is invalid when the source is an exchange offset' do
      offset = card_payment.new_exchange_offset_payment
      offset.save!
      expect(build_refund(offset)).not_to be_valid
    end

    it 'is invalid when the source is an external payment' do
      external = FactoryBot.create(:external_payment, order: order, amount: 5.0)
      expect(build_refund(external)).not_to be_valid
    end

    it 'is invalid when the source is a flex pass payment' do
      pass = FlexPassPayment.new(order: order, amount: 0, number_of_tickets: 2)
      expect(build_refund(pass)).not_to be_valid
    end
  end

  describe '#process!' do
    context 'with a credit card source' do
      it 'refunds the exact cents against the original transaction and stores the refund id' do
        refund = build_refund(card_payment, amount: BigDecimal('-10.00'))
        refund.idempotency_key = 'abc-refund-0'
        response = double('response', success?: true, authorization: 're_1')
        expect(gateway).to receive(:refund)
          .with(1000, 'TEST_TRANSACTION', hash_including(idempotency_key: 'abc-refund-0'))
          .and_return(response)

        refund.process!

        expect(refund).to be_persisted
        expect(refund.confirmation_code).to eq('re_1')
        expect(refund.transaction_id).to eq('re_1')
        expect(refund.processed_on).to be_present
      end

      it 'omits the idempotency key when none is set' do
        refund = build_refund(card_payment)
        response = double('response', success?: true, authorization: 're_2')
        expect(gateway).to receive(:refund) do |_cents, _reference, options|
          expect(options).not_to have_key(:idempotency_key)
          response
        end

        refund.process!
      end

      it 'raises CannotProcessPayment and saves nothing when the gateway declines' do
        refund = build_refund(card_payment)
        response = double('response', success?: false, message: 'card_declined', authorization: nil)
        allow(gateway).to receive(:refund).and_return(response)

        expect { refund.process! }.to raise_error(CannotProcessPayment, 'card_declined')
        expect(refund).not_to be_persisted
      end
    end

    context 'with a cash source' do
      let(:cash_order) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash) }
      let(:cash_payment) { cash_order.payments.grep(CashPayment).first }

      it 'records the refund without touching the gateway' do
        expect(PaymentProcessing).not_to receive(:gateway)
        refund = build_refund(cash_payment, amount: -4.0)

        refund.process!

        expect(refund).to be_persisted
        expect(refund.confirmation_code).to be_nil
        expect(refund.display_name).to eq('Cash Refund')
      end
    end
  end
end
