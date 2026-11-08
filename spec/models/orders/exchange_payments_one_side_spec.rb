require 'rails_helper'

# Exchange payment building attaches each payment through ONE side of the
# Order/Payment association, so the rows written are the same whether
# has_many_inversing is off (today) or on (the Rails 7.2 default). With
# inversing on, a payment built with `order:` lands in that order's in-memory
# payments and is autosaved by its save!, wanted or not.
RSpec.describe 'Exchange payments with and without has_many_inversing' do
  let(:gateway) { double('gateway') }
  let(:approved) { double('response', success?: true, authorization: 'ch_extra', params: {}, message: 'Approved') }
  let(:card_type) { FactoryBot.create(:credit_card_payment_type) }
  let(:cash_type) { FactoryBot.create(:cash_payment_type) }

  before do
    allow(PaymentProcessing).to receive(:gateway).and_return(gateway)
    allow(gateway).to receive(:purchase).and_return(approved)
    allow(gateway).to receive(:refund) do
      double('response', success?: true, authorization: "re_#{SecureRandom.hex(4)}", message: 'Refunded')
    end
  end

  # A pair of tickets on a later performance of the same production; +price+
  # adds a ticket class at that price.
  def exchange_for(original, payment_type:, price: nil)
    production = original.performance.production
    new_class = price && FactoryBot.create(:ticket_class, ticket_price: price, production: production,
                                                          class_code: "OS#{SecureRandom.hex(3).upcase}")
    performance = original.performance.dup
    performance.performance_date = original.performance.performance_date + 1.day
    performance.performance_code += SecureRandom.hex(2).upcase
    performance.save!
    exchange = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, performance: performance.reload,
                                                                        payment_type: payment_type)
    exchange.ticket_line_items[0].ticket_class = new_class if new_class
    with_card(exchange)
  end

  def with_card(order)
    order.credit_card_number = '4111111111111111'
    order.credit_card_type = 'bogus'
    order.credit_card_expiration_month = '12'
    order.credit_card_expiration_year = (Date.current.year + 1).to_s
    order.credit_card_verification_number = '999'
    order
  end

  def db_payments(order)
    Payment.where(order_id: order.id).to_a
  end

  [false, true].each do |inversing|
    context "with has_many_inversing #{inversing ? 'on' : 'off'}" do
      around do |example|
        old = ActiveRecord::Base.has_many_inversing
        ActiveRecord::Base.has_many_inversing = inversing
        example.run
      ensure
        ActiveRecord::Base.has_many_inversing = old
      end

      context 'when an exchange costs more and the difference is charged to a card' do
        it 'writes one difference payment and leaves both orders balanced' do
          original = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_credit_card).reload
          exchange = exchange_for(original, payment_type: card_type, price: 50.0)

          exchange.exchange_and_process_from!(original)

          charges = db_payments(exchange).grep(CreditCardPayment)
          expect(charges.size).to eq(1)
          expect(charges.first.amount).to eq(exchange.reload.total - original.payments.first.amount)
          expect(gateway).to have_received(:purchase).once
          expect(exchange.total_paid).to eq(exchange.total)
          expect(exchange.payments.to_a.size).to eq(db_payments(exchange).size)
          expect(original.reload.status).to eq(Order::EXCHANGED)
          expect(db_payments(original).sum(&:amount)).to eq(0)
        end
      end

      context 'when an exchange costs more and the difference is paid in cash' do
        it 'writes one difference payment and leaves both orders balanced' do
          original = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash).reload
          exchange = exchange_for(original, payment_type: cash_type, price: 50.0)

          exchange.exchange_and_process_from!(original)

          cash = db_payments(exchange).grep(CashPayment)
          expect(cash.size).to eq(1)
          expect(cash.first.amount).to eq(exchange.reload.total - original.payments.first.amount)
          expect(exchange.total_paid).to eq(exchange.total)
          expect(exchange.payments.to_a.size).to eq(db_payments(exchange).size)
          expect(original.reload.status).to eq(Order::EXCHANGED)
          expect(db_payments(original).sum(&:amount)).to eq(0)
        end
      end

      context 'when an exchange costs less and the difference is written off' do
        it 'writes one Carryover on the exchange order' do
          original = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_credit_card).reload
          exchange = exchange_for(original, payment_type: card_type, price: 1.0)

          exchange.exchange_and_process_from!(original)

          carryovers = db_payments(exchange).grep(PriceOverridePayment)
          expect(carryovers.size).to eq(1)
          expect(carryovers.first.amount).to be_negative
          expect(exchange.reload.total_paid).to eq(exchange.total)
        end
      end

      context 'when the original holds a $0 payment beside its card payment' do
        it 'writes no $0 exchange rows and keeps the offsets on the original' do
          original = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_credit_card)
          CashPayment.create!(amount: 0, order: original, payment_type: cash_type)
          original.reload
          card = original.payments.grep(CreditCardPayment).first
          exchange = exchange_for(original, payment_type: card_type)

          exchange.exchange_and_process_from!(original)

          expect(ExchangePayment.where(amount: 0).where(order_id: [original.id, exchange.id])).to be_empty
          expect(original.payments.map(&:order_id).uniq).to eq([original.id])
          expect(original.payments.to_a.size).to eq(db_payments(original).size)
          expect(db_payments(original).grep(ExchangePayment).map(&:amount)).to eq([-card.amount])
          expect(db_payments(exchange).grep(ExchangePayment).sum(&:amount)).to eq(card.amount)
          expect(exchange.payments.map(&:order_id).uniq).to eq([exchange.id])
          expect(exchange.reload.total_paid).to eq(exchange.total)
        end
      end

      context 'when an exchange-and-refund consumes the whole card offset' do
        it 'refunds the card and writes no $0 exchange rows' do
          original = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_credit_card).reload
          card = original.payments.first
          exchange = exchange_for(original, payment_type: card_type, price: 0.0)

          exchange.exchange_and_refund_from!(original)

          expect(ExchangePayment.where(amount: 0).where(order_id: [original.id, exchange.id])).to be_empty
          refunds = db_payments(original).grep(RefundPayment)
          expect(refunds.map(&:amount)).to eq([-card.amount])
          expect(original.payments.map(&:order_id).uniq).to eq([original.id])
          expect(original.payments.to_a.size).to eq(db_payments(original).size)
          expect(db_payments(original).sum(&:amount)).to eq(0)
          expect(original.reload.status).to eq(Order::EXCHANGED)
        end
      end
    end
  end
end
