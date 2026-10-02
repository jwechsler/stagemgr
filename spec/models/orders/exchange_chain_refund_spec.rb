require 'rails_helper'

# Refunding the last order of an exchange chain (ExchangeChainRefundable):
# exchange credits, offsets and Carryovers are reversed, every real tender in
# the chain is refunded on its own tender, the last order is REFUNDED and the
# earlier ones stay EXCHANGED.
RSpec.describe 'Refunding an exchange chain' do
  let(:gateway) { double('gateway') }
  let(:refunded) { double('response', success?: true, authorization: 're_test', message: 'Refunded') }
  let(:declined) { double('response', success?: false, authorization: nil, message: 'card_declined') }
  let(:approved) { double('response', success?: true, authorization: 'ch_extra', params: {}, message: 'Approved') }
  let(:card_type) { FactoryBot.create(:credit_card_payment_type) }

  before do
    allow(PaymentProcessing).to receive(:gateway).and_return(gateway)
    allow(gateway).to receive(:purchase).and_return(approved)
    allow(gateway).to receive(:refund).and_return(refunded)
  end

  # A pair of tickets on a later performance of the same production. +price+
  # adds a ticket class at that price (created before the performance so it
  # auto-attaches an allocation); class codes are unique because ticket_class
  # find_or_create ignores the production.
  def exchange_for(original, price: nil, payment_type: original.payment_type)
    production = original.performance.production
    new_class = price && FactoryBot.create(:ticket_class, ticket_price: price, production: production,
                                                          class_code: "CH#{SecureRandom.hex(3).upcase}")
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

  def exchange!(original, **options)
    exchange = exchange_for(original, **options)
    exchange.exchange_and_process_from!(original)
    exchange
  end

  def payments_total(order)
    order.reload.payments.sum(&:amount)
  end

  def expect_reversed(payment)
    reversals = ReversalPayment.where(payment_id: payment.id)
    expect(reversals.size).to eq(1)
    expect(reversals.first.amount).to eq(-payment.amount)
    expect(reversals.first.order_id).to eq(payment.order_id)
    expect(reversals.first.payment_type_id).to eq(payment.payment_type.id)
  end

  def card_refunds(order)
    order.reload.payments.grep(CreditCardPayment).select { |payment| payment.amount.negative? }
  end

  context 'when a card order was exchanged at the same price' do
    let(:original) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_credit_card) }
    let!(:card) { original.payments.first }
    let!(:exchange) { exchange!(original, payment_type: card_type) }

    it 'refunds the original card once, keyed to the refunded order, and reverses the exchange payments' do
      exchange.refund!

      expect(gateway).to have_received(:refund)
        .with((card.amount * 100).round, 'TEST_TRANSACTION',
              hash_including(idempotency_key: "#{exchange.uuid}-chain-refund-#{card.id}")).once
      expect(card_refunds(original).sum(&:amount)).to eq(-card.amount)
      (original.payments.grep(ExchangePayment) + exchange.payments.grep(ExchangePayment)).each do |payment|
        expect_reversed(payment)
      end
    end

    it 'marks only the last order REFUNDED and nets every order to zero' do
      exchange.refund!

      expect(exchange.reload.status).to eq(Order::REFUNDED)
      expect(original.reload.status).to eq(Order::EXCHANGED)
      expect(payments_total(original)).to eq(0)
      expect(payments_total(exchange)).to eq(0)
    end

    it 'is refundable only on the last order of the chain' do
      expect(exchange).to be_refundable
      expect(original.reload).not_to be_refundable
      expect(exchange.exchange_chain).to eq([exchange, original])
    end

    it 'leaves nothing left to reverse after the refund' do
      exchange.refund!

      expect(exchange.reload.refund_reversals).to be_empty
    end

    it 'does not reverse a payment that already has a reversal' do
      offset = original.payments.grep(ExchangePayment).first
      ReversalPayment.create!(amount: -offset.amount, order: original, payment_type: offset.payment_type,
                              source_payment: offset)

      exchange.reload.refund!

      expect(ReversalPayment.where(payment_id: offset.id).count).to eq(1)
      expect(payments_total(original)).to eq(0)
    end
  end

  context 'when the chain carries a $0 exchange payment with no tickets' do
    it 'does not reverse it and lists it as nothing to refund' do
      original = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_credit_card)
      card = original.payments.first
      exchange = exchange!(original, payment_type: card_type)
      empty = ExchangePayment.create!(amount: 0, order: original, payment_type: card.payment_type, source_payment: card)
      exchange.reload

      expect(exchange.refund_reversals).not_to include(empty)
      helper = Object.new.extend(ActionView::Helpers::NumberHelper, ActionView::Helpers::TextHelper,
                                 Admin::RefundOrdersHelper)
      expect(helper.refund_plan_line(empty, tenders: exchange.refund_tenders, reversals: exchange.refund_reversals))
        .to eq("#{empty.display_name.strip} $0.00: nothing to refund")

      exchange.refund!

      expect(ReversalPayment.where(payment_id: empty.id)).to be_empty
      expect(payments_total(original)).to eq(0)
      expect(payments_total(exchange)).to eq(0)
    end
  end

  context 'when the exchange cost less and the difference was written off' do
    it 'reverses the Carryover and refunds the whole original charge' do
      original = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_credit_card)
      card = original.payments.first
      exchange = exchange!(original, price: 1.0, payment_type: card_type)
      carryover = exchange.payments.override_payments_only.first
      expect(carryover.amount).to be_negative

      exchange.refund!

      expect_reversed(carryover)
      expect(gateway).to have_received(:refund).once.with((card.amount * 100).round, 'TEST_TRANSACTION', anything)
      expect(payments_total(original)).to eq(0)
      expect(payments_total(exchange)).to eq(0)
    end
  end

  context 'when the exchange cost more and the difference was charged to a card' do
    let(:original) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_credit_card) }
    let!(:card) { original.payments.first }
    let!(:exchange) { exchange!(original, price: 50.0, payment_type: card_type) }
    let(:extra_charge) { exchange.payments.grep(CreditCardPayment).first }

    it 'refunds both cards, oldest first, each with its own idempotency key' do
      exchange.refund!

      expect(gateway).to have_received(:refund)
        .with((card.amount * 100).round, 'TEST_TRANSACTION',
              hash_including(idempotency_key: "#{exchange.uuid}-chain-refund-#{card.id}")).ordered
      expect(gateway).to have_received(:refund)
        .with((extra_charge.amount * 100).round, 'ch_extra',
              hash_including(idempotency_key: "#{exchange.uuid}-chain-refund-#{extra_charge.id}")).ordered
      expect(payments_total(original)).to eq(0)
      expect(payments_total(exchange)).to eq(0)
    end

    it 'rolls back every row and status when a card refund is declined' do
      allow(gateway).to receive(:refund).and_return(refunded, declined)
      payment_count = Payment.count

      expect { exchange.refund! }.to raise_error(CannotProcessPayment, 'card_declined')

      expect(Payment.count).to eq(payment_count)
      expect(exchange.reload.status).to eq(Order::PROCESSED)
      expect(original.reload.status).to eq(Order::EXCHANGED)
    end
  end

  context 'when the first link was an exchange and refund' do
    it 'refunds only what is left on the original card' do
      original = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_credit_card)
      card = original.payments.first
      exchange = exchange_for(original, price: 1.0)
      exchange.exchange_and_refund_from!(original)
      remaining = card.reload.refundable_amount
      expect(remaining).to be_between(0.01, card.amount - 0.01)

      exchange.reload.refund!

      expect(gateway).to have_received(:refund).with((remaining * 100).round, 'TEST_TRANSACTION',
                                                     hash_including(idempotency_key: /chain-refund-#{card.id}\z/))
      expect(payments_total(original)).to eq(0)
      expect(payments_total(exchange)).to eq(0)
    end
  end

  context 'when the original was paid in cash' do
    it 'records the cash refund on the original without a gateway call' do
      original = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash)
      cash = original.payments.first
      exchange = exchange!(original)

      exchange.refund!

      expect(gateway).not_to have_received(:refund)
      expect(original.reload.payments.grep(CashPayment).map(&:amount)).to contain_exactly(cash.amount, -cash.amount)
      expect(payments_total(original)).to eq(0)
      expect(payments_total(exchange)).to eq(0)
    end
  end

  context 'when the original was paid by check' do
    it 'reverses the check on the original' do
      check_type = FactoryBot.create(:check_payment_type)
      check_type.update!(report_as_sales_collected: true)
      original = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, payment_type: check_type)
      check = CheckPayment.create!(order: original, payment_type: check_type, amount: original.total_due)
      original.payments.reload
      original.update!(status: Order::PROCESSED)
      exchange = exchange!(original)

      exchange.refund!

      expect(ReversalPayment.where(payment_id: check.id).sum(:amount)).to eq(-check.amount)
      expect(payments_total(original)).to eq(0)
      expect(payments_total(exchange)).to eq(0)
    end
  end

  context 'with three orders in the chain' do
    let(:first) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_credit_card) }
    let!(:card) { first.payments.first }
    let!(:second) { exchange!(first, payment_type: card_type) }
    let!(:third) { exchange!(second, payment_type: card_type) }

    it 'refunds the first card, reverses every exchange payment and nets every order to zero' do
      expect(third.exchange_chain).to eq([third, second, first])

      third.refund!

      expect(gateway).to have_received(:refund).once.with((card.amount * 100).round, 'TEST_TRANSACTION', anything)
      [first, second, third].each do |order|
        order.reload.payments.grep(ExchangePayment).each { |payment| expect_reversed(payment) }
        expect(payments_total(order)).to eq(0)
      end
      expect([first, second, third].map { |order| order.reload.status })
        .to eq([Order::EXCHANGED, Order::EXCHANGED, Order::REFUNDED])
    end

    it 'can be refunded only from the last order' do
      expect([first, second, third].map { |order| order.reload.refundable? }).to eq([false, false, true])
    end
  end

  context 'when the original was paid with a flex pass' do
    it 'keeps the offset of the released pass and refunds the later card charge' do
      original = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_flex_pass)
      pass_payment = original.payments.grep(FlexPassPayment).first
      pass_payment.update_column(:amount, 4.0) # a pass ticket class with a face value
      original.payments.reload
      exchange = exchange!(original, payment_type: card_type)
      offset = original.payments.grep(ExchangePayment).first
      credit = exchange.payments.grep(ExchangePayment).first
      charge = exchange.payments.grep(CreditCardPayment).first
      expect(pass_payment.reload.number_of_tickets).to eq(0)

      exchange.refund!

      expect(ReversalPayment.where(payment_id: offset.id)).to be_empty
      expect_reversed(credit)
      expect(gateway).to have_received(:refund).once.with((charge.amount * 100).round, 'ch_extra', anything)
      expect(payments_total(original)).to eq(0)
      expect(payments_total(exchange)).to eq(0)
    end
  end

  context 'when the original was paid with a membership' do
    let(:original) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_membership) }
    let!(:membership_payment) { original.payments.grep(MembershipPayment).first }
    let(:membership) { membership_payment.membership }

    def expect_chain_settled(exchange)
      expect(exchange.reload.status).to eq(Order::REFUNDED)
      expect(original.reload.status).to eq(Order::EXCHANGED)
      [original, exchange].each do |order|
        expect(payments_total(order)).to eq(0)
        expect(order.payments.sum { |payment| payment.number_of_tickets.to_i }).to eq(0)
      end
    end

    it 'releases the membership tickets on both orders of a membership-to-membership chain' do
      # Another production: a member's repeat visit to the same show is door-only.
      exchange = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, payment_type: original.payment_type)
      exchange.member_code = original.member_code
      exchange.exchange_and_process_from!(original)
      expect(exchange.reload.payments.grep(MembershipPayment).sum(&:number_of_tickets)).to eq(2)

      exchange.refund!

      expect_chain_settled(exchange)
      expect(original.payments.grep(MembershipPayment).map(&:number_of_tickets)).to contain_exactly(2, -2)
      expect(exchange.payments.grep(MembershipPayment).map(&:number_of_tickets)).to contain_exactly(2, -2)
      expect_reversed(original.payments.grep(ExchangePayment).first)
      expect(gateway).not_to have_received(:refund)
    end

    it 'releases the membership tickets when the exchange was into a card order' do
      exchange = exchange!(original, payment_type: card_type)

      exchange.refund!

      expect_chain_settled(exchange)
      expect(original.payments.grep(MembershipPayment).map(&:number_of_tickets)).to contain_exactly(2, -2)
      (original.payments.grep(ExchangePayment) + exchange.payments.grep(ExchangePayment)).each do |payment|
        expect_reversed(payment)
      end
      expect(membership.membership_payments.sum(:number_of_tickets)).to eq(0)
    end

    it 'refuses a second refund of the same order and adds no payments' do
      exchange = exchange!(original, payment_type: card_type)
      stale = TicketOrder.find(exchange.id)
      exchange.refund!
      payment_count = Payment.count

      expect { stale.refund! }.to raise_error(Order::RefundNotAllowed, /already been refunded/)

      expect(Payment.count).to eq(payment_count)
    end
  end

  context 'when an exchange begins after the order was loaded' do
    it 'refuses the refund under the row lock and changes nothing' do
      original = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_credit_card)
      exchange = exchange!(original, payment_type: card_type)
      stale = TicketOrder.find(exchange.id)
      exchange.update_columns(status: Order::RELEASING)
      payment_count = Payment.count

      expect { stale.refund! }.to raise_error(Order::RefundNotAllowed, /part-way through an exchange \(Releasing\)/)

      expect(Payment.count).to eq(payment_count)
      expect(exchange.reload.status).to eq(Order::RELEASING)
      expect(gateway).not_to have_received(:refund)
    end
  end

  context 'when an exchanged order is refunded directly' do
    it 'refunds only that order, leaving the credit it passed on in place' do
      original = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_credit_card)
      middle = exchange!(original, payment_type: card_type)
      last = exchange!(middle, payment_type: card_type)

      middle.reload.refund!

      expect(ReversalPayment.count).to eq(0)
      expect(last.reload.payments.grep(ExchangePayment).sum(&:amount)).to eq(last.total_due)
    end
  end

  context 'with reserved seating' do
    it 'releases the last order’s seats' do
      original = FactoryBot.create(:ticket_order, :reserved_seating, :for_a_pair_of_tickets, :paid_with_credit_card)
      exchange = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, performance: original.performance,
                                                                          payment_type: card_type)
      exchange.exchange_and_process_from!(original)
      expect(exchange.reload.seats).not_to be_empty

      exchange.refund!

      expect(exchange.reload.status).to eq(Order::REFUNDED)
      expect(exchange.seats).to be_empty
      expect(original.reload.seats).to be_empty
      expect(original.status).to eq(Order::EXCHANGED)
    end
  end
end
