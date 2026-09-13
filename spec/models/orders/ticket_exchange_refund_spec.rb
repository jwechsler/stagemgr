require 'rails_helper'

# Exchange-and-refund: the price difference goes back to the original cash,
# check or card payments as RefundPayments on the ORIGINAL order, and the
# Stripe call is the last step before commit.
RSpec.describe 'TicketOrder#exchange_and_refund_from!' do
  let(:gateway) { double('gateway') }
  let(:success) { double('response', success?: true, authorization: 're_test') }
  let(:decline) { double('response', success?: false, message: 'card_declined', authorization: nil) }

  before { allow(PaymentProcessing).to receive(:gateway).and_return(gateway) }

  # A second performance of the same production with a $1.00 ticket class, and
  # a pair-of-tickets order against it (total_due 2.00), mirroring the
  # down-price fixture in ticket_order_spec.rb.
  def cheaper_exchange_for(original)
    # The class must exist before the performance is saved so it auto-attaches an allocation.
    cheap_class = FactoryBot.create(:ticket_class, ticket_price: 1.0, class_code: 'EXCH',
                                                   production: original.performance.production)
    performance2 = original.performance.dup
    performance2.performance_date = original.performance.performance_date + 1.day
    performance2.performance_code += 'R'
    performance2.save!
    performance2.reload
    exchange = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, performance: performance2)
    exchange.ticket_line_items[0].ticket_class = cheap_class
    exchange.uuid = 'exch-uuid'
    exchange
  end

  def same_price_exchange_for(original)
    performance2 = original.performance.dup
    performance2.performance_date = original.performance.performance_date + 1.day
    performance2.performance_code += 'S'
    performance2.save!
    performance2.reload
    FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, performance: performance2)
  end

  def pay_by_card!(order, amount)
    order.payments << FactoryBot.create(:credit_card_payment, order: order, amount: amount,
                                                              transaction_id: 'pi_test', confirmation_code: 'pi_test')
  end

  def settle!(order)
    order.status = Order::PROCESSED
    order.save!
    order
  end

  context 'when the original was paid by card' do
    let(:original) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_credit_card) }
    let(:card) { original.payments.grep(CreditCardPayment).first }

    it 'refunds the difference to the card and balances both orders' do
      exchange = cheaper_exchange_for(original)
      difference = original.total_paid - exchange.total_due
      expect(difference).to be > 0
      expect(gateway).to receive(:refund)
        .with((difference * 100).to_i, 'TEST_TRANSACTION', hash_including(idempotency_key: 'exch-uuid-refund-0'))
        .once.and_return(success)

      exchange.exchange_and_refund_from!(original)

      original.reload
      expect(original.status).to eq(Order::EXCHANGED)
      expect(original.total_paid).to eq(0)
      expect(original.payments.map(&:class)).to contain_exactly(CreditCardPayment, ExchangePayment, RefundPayment)

      refund = original.payments.grep(RefundPayment).first
      expect(refund.amount).to eq(-difference)
      expect(refund.source_payment).to eq(card)
      expect(refund.payment_type).to eq(card.payment_type)
      expect(refund.confirmation_code).to eq('re_test')
      expect(refund.note).to eq("Refund for exchange to order ##{exchange.id}")

      offset = original.payments.grep(ExchangePayment).first
      expect(offset.amount).to eq(-exchange.total_due)

      exchange.reload
      expect(exchange.status).to eq(Order::PROCESSED)
      expect(exchange.total_paid).to eq(exchange.total_due)
      expect(exchange.payments.override_payments_only).to be_empty
      expect(exchange.payments.grep(CreditCardPayment)).to be_empty
      expect(exchange.exchange_source_id).to eq(original.id)
    end

    it 'rolls back the whole exchange when the gateway declines' do
      exchange = cheaper_exchange_for(original)
      allow(gateway).to receive(:refund).and_return(decline)
      payment_count = Payment.count

      expect { exchange.exchange_and_refund_from!(original) }.to raise_error(CannotProcessPayment, 'card_declined')

      original.reload
      expect(original.status).to eq(Order::PROCESSED)
      expect(original.payments.size).to eq(1)
      expect(Order.where(exchange_source_id: original.id)).to be_empty
      expect(Payment.count).to eq(payment_count)
      expect(RefundPayment.count).to eq(0)
    end

    it 'refuses when the new order does not cost less' do
      exchange = same_price_exchange_for(original)
      expect(gateway).not_to receive(:refund)

      expect { exchange.exchange_and_refund_from!(original) }
        .to raise_error(ExchangeRefundable::RefundNotPossible, /Nothing to refund/)
      expect(original.reload.status).to eq(Order::PROCESSED)
      expect(Order.where(exchange_source_id: original.id)).to be_empty
    end

    it 'still writes off the difference as a Carryover on a plain exchange' do
      exchange = cheaper_exchange_for(original)
      difference = original.total_paid - exchange.total_due
      expect(gateway).not_to receive(:refund)

      exchange.exchange_and_process_from!(original)

      expect(exchange.total_override_payments).to eq(-difference)
      expect(RefundPayment.count).to eq(0)
    end
  end

  context 'when the original carried an exchange service fee the theater keeps' do
    it 'refunds only the ticket difference and leaves the fee on the original' do
      original = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :with_twenty_dollar_service_item)
      pay_by_card!(original, original.total_due)
      settle!(original)
      fee = original.service_line_items.sum(:amount)
      exchange = cheaper_exchange_for(original)
      ticket_difference = original.total_paid - fee - exchange.total_due
      expect(gateway).to receive(:refund).with((ticket_difference * 100).to_i, 'pi_test', anything).and_return(success)

      exchange.exchange_and_refund_from!(original)

      original.reload
      expect(original.payments.grep(RefundPayment).sum(&:amount)).to eq(-ticket_difference)
      expect(original.total_paid).to eq(fee)
      expect(exchange.reload.total_paid).to eq(exchange.total_due)
    end
  end

  context 'when the original was paid in cash' do
    it 'records the refund without a gateway call' do
      original = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash)
      exchange = cheaper_exchange_for(original)
      difference = original.total_paid - exchange.total_due
      expect(gateway).not_to receive(:refund)

      exchange.exchange_and_refund_from!(original)

      refund = original.reload.payments.grep(RefundPayment).first
      expect(refund.amount).to eq(-difference)
      expect(refund.display_name).to eq('Cash Refund')
      expect(refund.confirmation_code).to be_nil
      expect(original.total_paid).to eq(0)
      expect(exchange.reload.total_paid).to eq(exchange.total_due)
    end
  end

  context 'when the original was not paid with currency' do
    it 'refuses a flex pass original and leaves it untouched' do
      original = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_flex_pass)
      exchange = cheaper_exchange_for(original)
      exchange.payment_type = original.payment_type

      expect { exchange.exchange_and_refund_from!(original) }
        .to raise_error(ExchangeRefundable::RefundNotPossible)
      expect(original.reload.status).to eq(Order::PROCESSED)
      expect(RefundPayment.count).to eq(0)
    end

    it 'refuses when the cash portion cannot cover the difference' do
      original = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets)
      cash_part = BigDecimal('1.00')
      original.payments << FactoryBot.create(:cash_payment, order: original, amount: cash_part)
      original.payments << FactoryBot.create(:external_payment, order: original, amount: original.total_due - cash_part)
      settle!(original)
      exchange = cheaper_exchange_for(original)
      expect(gateway).not_to receive(:refund)

      expect { exchange.exchange_and_refund_from!(original) }
        .to raise_error(ExchangeRefundable::RefundNotPossible, /Only \$1\.00 of/)
      expect(original.reload.payments.size).to eq(2)
      expect(Order.where(exchange_source_id: original.id)).to be_empty
    end
  end
end
