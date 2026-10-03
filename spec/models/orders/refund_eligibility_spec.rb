require 'rails_helper'

# Order#refund_blockers: the reasons the refund page and
# Admin::RefundOrdersController refuse a refund.
RSpec.describe RefundEligibility do
  let(:card_type) { FactoryBot.create(:credit_card_payment_type) }

  before do
    gateway = double('gateway')
    allow(PaymentProcessing).to receive(:gateway).and_return(gateway)
    allow(gateway).to receive(:purchase)
      .and_return(double('response', success?: true, authorization: 'ch_x', params: {}, message: 'Approved'))
  end

  def exchange!(original)
    performance = original.performance.dup
    performance.performance_date = original.performance.performance_date + 1.day
    performance.performance_code += SecureRandom.hex(2).upcase
    performance.save!
    exchange = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, performance: performance.reload,
                                                                        payment_type: card_type)
    exchange.exchange_and_process_from!(original)
    exchange
  end

  let(:order) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_credit_card) }

  it 'has no blockers for a processed order paid by card' do
    expect(order.refund_blockers).to be_empty
    expect(order).to be_refund_allowed
  end

  it 'blocks an order that has not been processed' do
    order.update_columns(status: Order::HOLD)

    expect(order.reload.refund_blockers).to eq(["Order ##{order.id} can't be refunded while it is Hold."])
  end

  it 'blocks an order holding a payment kind the refund cannot return' do
    order.payments << PriceOverridePayment.new(amount: 5, order: order, source_payment_type: order.payment_type)

    expect(order.refund_blockers).to eq(["Refunds don't handle #{order.payments.last.display_name} payments."])
  end

  it 'blocks an exchanged order and points at the order it was exchanged for' do
    exchange = exchange!(order)

    expect(order.reload.refund_blockers).to contain_exactly(
      "Order ##{order.id} can't be refunded while it is Exchanged.",
      "Order ##{order.id} was exchanged for order ##{exchange.id}; refund the last order of its exchange chain."
    )
    expect(exchange.refund_blockers).to be_empty
  end

  it 'blocks the last order while an exchange from it is in progress' do
    exchange = exchange!(order)
    onward = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, performance: exchange.performance)
    onward.update_columns(exchange_source_id: exchange.id, status: Order::EXCHANGING)

    expect(exchange.reload.refund_blockers).to include(
      "Order ##{onward.id} is part-way through an exchange (Exchanging).",
      "Order ##{exchange.id} was exchanged for order ##{onward.id}; refund the last order of its exchange chain."
    )
  end

  it 'ignores a cancelled onward exchange' do
    exchange = exchange!(order)
    onward = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, performance: exchange.performance)
    onward.update_columns(exchange_source_id: exchange.id, status: Order::CANCELED)

    expect(exchange.reload.refund_blockers).to be_empty
  end

  it 'spells its given-up statuses the way Order does' do
    expect(RefundEligibility::GIVEN_UP_STATUSES).to eq([Order::EXCHANGED, Order::SPLIT, Order::CANCELED])
  end

  it 'has no blockers for a refundable donation' do
    donation = FactoryBot.create(:donation_order_for_one_thousand_dollars, status: Order::PROCESSED)

    expect(donation.refund_blockers).to be_empty
  end
end
