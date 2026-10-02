# Refund of the last order of an exchange chain (A -> B -> C, A and B
# EXCHANGED). Order#refund! still reverses only C's line items and marks only C
# REFUNDED; this concern replaces the payment half so every order in the chain
# nets to zero: exchange credits, offsets and Carryovers are cancelled with
# ReversalPayments, then every real tender (card, cash, check, pass) on any
# order in the chain is refunded on its own tender. A and B stay EXCHANGED.
module ExchangeChainRefundable
  extend ActiveSupport::Concern

  # Moved between the orders of a chain rather than collected from the patron,
  # so a chain refund reverses them instead of refunding them.
  REVERSED_PAYMENT_CLASSES = [ExchangePayment, PriceOverridePayment].freeze
  # Never refunded or reversed themselves: they already undo another payment.
  SETTLING_PAYMENT_CLASSES = (REVERSED_PAYMENT_CLASSES + [ReversalPayment, RefundPayment]).freeze

  # This order and the orders it was exchanged from, newest first.
  def exchange_chain
    chain = [self]
    source = exchange_source
    while source && chain.exclude?(source)
      chain << source
      source = source.exchange_source
    end
    chain
  end

  # Oldest order first, so the original sale is refunded before later charges.
  def refund_tenders
    return super if exchange_source.nil?

    exchange_chain.reverse.flat_map { |order| chain_refund_tenders(order) }
  end

  def refund_reversals
    return super if exchange_source.nil?

    exchange_chain.reverse.flat_map { |order| chain_refund_reversals(order) }
  end

  protected

  # DB-only work first (reversals, then cash/check/pass refunds), card refunds
  # last, so a gateway failure rolls back everything in Order#refund!'s
  # transaction before any further card is touched.
  def refund_payments!(refund_note)
    return super if exchange_source.nil?

    Order.where(id: exchange_chain.map(&:id)).lock.pluck(:id)
    tenders = refund_tenders
    refund_reversals.each { |payment| reverse_for_chain_refund!(payment) }
    cards, others = tenders.partition { |payment| payment.is_a?(CreditCardPayment) }
    others.each { |payment| payment.refund!(nil, refund_note) }
    cards.each do |card|
      card.refund!(nil, refund_note, idempotency_key: "#{uuid}-chain-refund-#{card.id}")
    end
  end

  private

  def chain_refund_tenders(order)
    order.payments.select do |payment|
      payment.refundable? && SETTLING_PAYMENT_CLASSES.none? { |klass| payment.is_a?(klass) }
    end
  end

  # Skips payments already reversed, so a retried refund never reverses twice.
  def chain_refund_reversals(order)
    reversed_ids = Payment.where(type: 'ReversalPayment', payment_id: order.payments.map(&:id)).pluck(:payment_id)
    order.payments.select do |payment|
      REVERSED_PAYMENT_CLASSES.any? { |klass| payment.is_a?(klass) } &&
        reversed_ids.exclude?(payment.id) && !offsets_kept_tender?(payment)
    end
  end

  # An offset of a tender the refund leaves alone still balances that tender:
  # a flex pass whose tickets the exchange already returned (release_tickets!
  # zeroed them), or a comp that was never collected. Reversing it would leave
  # the order owing the tender's amount.
  def offsets_kept_tender?(payment)
    source = payment.source_payment
    payment.is_a?(ExchangePayment) && source.present? &&
      SETTLING_PAYMENT_CLASSES.none? { |klass| source.is_a?(klass) } && !source.refundable?
  end

  def reverse_for_chain_refund!(payment)
    ReversalPayment.create!(
      amount: -payment.amount,
      number_of_tickets: payment.number_of_tickets.present? ? -payment.number_of_tickets : nil,
      order: payment.order,
      payment_type: payment.payment_type,
      source_payment: payment,
      note: "Refund of exchange chain from order ##{id}"
    )
  end
end
