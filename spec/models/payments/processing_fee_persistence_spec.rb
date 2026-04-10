require 'rails_helper'

RSpec.describe "Processing fee persistence", type: :model do
  let(:order) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :general_admission) }
  let(:credit_card_payment_type) { PaymentType.find_by(display_name: 'Credit Card') || FactoryBot.create(:credit_card_payment_type) }
  let(:cash_payment_type) { PaymentType.find_by(display_name: 'Cash') || FactoryBot.create(:cash_payment_type) }

  let(:cc_attrs) do
    { card_type: 'Visa', card_last_four: '4242', card_expiration_month: 12,
      card_expiration_year: 2030, confirmation_code: 'ch_test' }
  end

  describe CreditCardPayment do
    it "persists the processing fee on save (post-July 2021)" do
      payment = CreditCardPayment.create!(
        **cc_attrs,
        order: order,
        amount: 50.00,
        payment_type: credit_card_payment_type,
        transaction_id: 'ch_test_persist1'
      )

      expected_fee = (0.30 + 50.00 * 0.035).round(2)
      expect(payment.processing_fee).to eq(expected_fee)
      expect(payment.reload.read_attribute(:processing_fee).to_f).to eq(expected_fee)
    end

    it "persists the processing fee on save (pre-July 2021)" do
      payment = CreditCardPayment.new(
        **cc_attrs,
        order: order,
        amount: 50.00,
        payment_type: credit_card_payment_type,
        transaction_id: 'ch_test_persist2',
        created_at: Date.parse("01-01-2020")
      )
      payment.save!

      expected_fee = (0.22 + 50.00 * 0.04).round(2)
      expect(payment.processing_fee).to eq(expected_fee)
    end

    it "persists 0 for refund payments (negative amount)" do
      payment = CreditCardPayment.create!(
        **cc_attrs,
        order: order,
        amount: -50.00,
        payment_type: credit_card_payment_type,
        transaction_id: 'ch_test_refund1'
      )

      expect(payment.processing_fee).to eq(0)
    end

    it "does not recalculate on subsequent saves" do
      payment = CreditCardPayment.create!(
        **cc_attrs,
        order: order,
        amount: 50.00,
        payment_type: credit_card_payment_type,
        transaction_id: 'ch_test_immutable'
      )

      original_fee = payment.processing_fee
      payment.update!(amount: 100.00)

      expect(payment.reload.processing_fee.to_f).to eq(original_fee)
    end
  end

  describe RecurringPayment do
    it "persists the processing fee with proper rounding" do
      payment = RecurringPayment.create!(
        order: order,
        amount: 25.00,
        payment_type: credit_card_payment_type
      )

      expected_fee = (0.22 + 25.00 * 0.022).round(2)
      expect(payment.processing_fee).to eq(expected_fee)
    end
  end

  describe CashPayment do
    it "persists 0 processing fee" do
      payment = CashPayment.create!(
        order: order,
        amount: 50.00,
        payment_type: cash_payment_type
      )

      expect(payment.processing_fee).to eq(0)
    end
  end

  describe ExternalPayment do
    it "persists 0 processing fee" do
      payment = ExternalPayment.create!(
        order: order,
        amount: 50.00,
        payment_type: FactoryBot.create(:external_payment_type)
      )

      expect(payment.processing_fee).to eq(0)
    end
  end

  describe Order do
    it "aggregates processing fees from persisted values" do
      CreditCardPayment.create!(
        **cc_attrs,
        order: order,
        amount: 50.00,
        payment_type: credit_card_payment_type,
        transaction_id: 'ch_test_agg1'
      )
      CreditCardPayment.create!(
        **cc_attrs,
        order: order,
        amount: 30.00,
        payment_type: credit_card_payment_type,
        transaction_id: 'ch_test_agg2'
      )

      fee1 = (0.30 + 50.00 * 0.035).round(2)
      fee2 = (0.30 + 30.00 * 0.035).round(2)

      order.reload
      expect(order.processing_fee.to_f).to eq((fee1 + fee2).round(2))
    end
  end
end
