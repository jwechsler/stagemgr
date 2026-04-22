require 'rails_helper'

RSpec.describe RevenueCalculator, type: :service do
  let(:production) { FactoryBot.create(:production) }
  let(:performance) { FactoryBot.create(:performance, production: production) }

  describe '.for' do
    context 'with an empty scope' do
      it 'returns zero totals' do
        result = RevenueCalculator.for(TicketOrder.none)
        expect(result.cash_collected).to eq(0)
        expect(result.cash_reportable).to eq(0)
        expect(result.ticketing_fees).to eq(0)
        expect(result.processing_fees).to eq(0)
        expect(result.ticket_count).to eq(0)
        expect(result.comp_count).to eq(0)
        expect(result.order_count).to eq(0)
        expect(result.net).to eq(0)
      end
    end

    context 'with a settled ticket order paid with credit card' do
      let!(:order) do
        FactoryBot.create(:ticket_order,
          :for_a_single_ticket,
          :paid_with_credit_card,
          performance: performance)
      end

      before do
        order.payments.first.update!(processing_fee: 0.30)
      end

      it 'includes the order in cash_collected and cash_reportable' do
        result = RevenueCalculator.for(performance.orders)
        expect(result.order_count).to eq(1)
        expect(result.cash_collected).to  eq(order.total_paid)
        expect(result.cash_reportable).to eq(order.total_paid)
      end

      it 'sums processing_fees from payments' do
        result = RevenueCalculator.for(performance.orders)
        expect(result.processing_fees).to eq(BigDecimal('0.30'))
      end

      it 'counts the ticket as non-comp' do
        result = RevenueCalculator.for(performance.orders)
        expect(result.ticket_count).to eq(1)
        expect(result.comp_count).to eq(0)
      end
    end

    context 'filtering by status' do
      it 'excludes orders that are not in the status filter' do
        FactoryBot.create(:ticket_order, :for_a_single_ticket, performance: performance) # status: NEW — excluded
        FactoryBot.create(:ticket_order, :for_a_single_ticket, :paid_with_credit_card, performance: performance) # PROCESSED — included

        result = RevenueCalculator.for(performance.orders)
        expect(result.order_count).to eq(1)
      end
    end

    context 'with refund/exchange offset payments' do
      let!(:order) do
        FactoryBot.create(:ticket_order,
          :for_a_single_ticket,
          :paid_with_credit_card,
          performance: performance)
      end

      it 'nets negative offset payments against cash_collected' do
        original = order.total_paid
        offset_payment = order.payments.first.new_exchange_offset_payment
        offset_payment.save!
        order.update!(status: Order::EXCHANGED)

        result = RevenueCalculator.for(performance.orders)
        expect(result.order_count).to eq(1)
        expect(result.cash_collected).to eq(0) # original + offset = 0
        expect(original).to be > 0
      end
    end

    context 'when cash_reportable differs from cash_collected' do
      it 'excludes payments whose payment_type is not report_as_sales_collected' do
        order = FactoryBot.create(:ticket_order, :for_a_single_ticket, :paid_with_credit_card, performance: performance)
        # Flip the payment's type so its amount is in cash_collected but NOT cash_reportable
        order.payments.first.payment_type.update!(report_as_sales_collected: false)

        result = RevenueCalculator.for(performance.orders)
        expect(result.cash_collected).to  eq(order.total_paid)
        expect(result.cash_reportable).to eq(0)
      end
    end

    context 'accepting a pre-loaded array' do
      let!(:order) do
        FactoryBot.create(:ticket_order,
          :for_a_single_ticket,
          :paid_with_credit_card,
          performance: performance)
      end

      it 'works with an Array of orders and applies the status filter' do
        orders = performance.orders.to_a
        result = RevenueCalculator.for(orders)
        expect(result.order_count).to eq(1)
        expect(result.cash_collected).to eq(order.total_paid)
      end

      it 'filters out statuses not in the filter when passed an array' do
        FactoryBot.create(:ticket_order, :for_a_single_ticket, performance: performance) # NEW
        orders = performance.orders.to_a
        result = RevenueCalculator.for(orders)
        expect(result.order_count).to eq(1)
      end
    end
  end

  describe '.for_production' do
    it 'aggregates across all performances of the production' do
      perf2 = FactoryBot.create(:performance, production: production, performance_time: Time.now + 2.hours)
      FactoryBot.create(:ticket_order, :for_a_single_ticket, :paid_with_credit_card, performance: performance)
      FactoryBot.create(:ticket_order, :for_a_single_ticket, :paid_with_credit_card, performance: perf2)

      result = RevenueCalculator.for_production(production)
      expect(result.order_count).to eq(2)
    end
  end
end
