require 'rails_helper'

RSpec.describe PriceOverridePayment do
  context 'payment_type for exchange orders' do
    it 'inherits reporting flags from the source payment type' do
      source_payment_type = FactoryBot.create(:external_payment_type)
      source_payment_type.update!(report_as_sales_collected: true)

      payment = PriceOverridePayment.new(amount: -5.0, source_payment_type: source_payment_type)
      override_type = payment.payment_type

      expect(override_type).to be_a(PriceOverridePaymentType)
      expect(override_type.report_as_sales_collected?).to eq(true)
      expect(override_type.report_as_production_revenue?).to eq(true)
    end

    it 'defaults reporting flags to false when source payment type does not report as sales' do
      source_payment_type = FactoryBot.create(:external_payment_type)
      source_payment_type.update!(report_as_sales_collected: false)

      payment = PriceOverridePayment.new(amount: -5.0, source_payment_type: source_payment_type)
      override_type = payment.payment_type

      expect(override_type).to be_a(PriceOverridePaymentType)
      expect(override_type.report_as_sales_collected?).to eq(false)
      expect(override_type.report_as_production_revenue?).to eq(false)
    end

    it 'defaults reporting flags to false when there is no source payment type' do
      payment = PriceOverridePayment.new(amount: -5.0)
      override_type = payment.payment_type

      expect(override_type).to be_a(PriceOverridePaymentType)
      expect(override_type.report_as_sales_collected?).to eq(false)
      expect(override_type.report_as_production_revenue?).to eq(false)
    end

    it 'does not create duplicate PriceOverridePaymentType records' do
      source_payment_type = FactoryBot.create(:external_payment_type)
      source_payment_type.update!(report_as_sales_collected: true)

      initial_count = PriceOverridePaymentType.count

      payment1 = PriceOverridePayment.new(amount: -5.0, source_payment_type: source_payment_type)
      payment2 = PriceOverridePayment.new(amount: -3.0, source_payment_type: source_payment_type)
      payment3 = PriceOverridePayment.new(amount: -1.0)

      payment1.payment_type
      payment2.payment_type
      payment3.payment_type

      expect(PriceOverridePaymentType.count).to eq(initial_count + 2)
    end

    it 'reuses existing PriceOverridePaymentType across multiple exchange orders' do
      ticket_order1 = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_external)
      ticket_order2 = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_external)

      payment1 = PriceOverridePayment.new(amount: -5.0, source_payment_type: ticket_order1.payment_type)
      payment2 = PriceOverridePayment.new(amount: -3.0, source_payment_type: ticket_order2.payment_type)

      expect(payment1.payment_type.id).to eq(payment2.payment_type.id)
    end

    it 'always displays as Carryover' do
      payment = PriceOverridePayment.new(amount: -5.0)
      expect(payment.payment_type.display_name).to eq('Carryover')
    end
  end
end
