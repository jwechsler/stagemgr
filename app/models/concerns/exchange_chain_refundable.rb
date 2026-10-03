# Refund of the last order of an exchange chain (A -> B -> C, A and B
# EXCHANGED). Order#refund! still reverses only C's line items and marks only C
# REFUNDED; this concern replaces the payment half so every order in the chain
# nets to zero: exchange credits, offsets and Carryovers are cancelled with
# ReversalPayments, then every real tender (card, cash, check, pass) on any
# order in the chain is refunded on its own tender. A and B stay EXCHANGED.
# Only the last order may be refunded (#refund_blockers); an order already
# exchanged onward that is refunded anyway (Membership#cancel_future_reservations
# calls refund! directly) keeps the plain single-order refund.
module ExchangeChainRefundable
  extend ActiveSupport::Concern

  # An order in either status is part-way through an exchange.
  MID_EXCHANGE_STATUSES = [Order::RELEASING, Order::EXCHANGING].freeze

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

  def refund_blockers
    onward = exchange_successors.pluck(:id).map do |successor_id|
      "Order ##{id} was exchanged for order ##{successor_id}; refund the last order of its exchange chain."
    end
    super + onward + branched_chain_blockers
  end

  # Oldest order first, so the original sale is refunded before later charges.
  def refund_tenders
    return super unless chain_refund?

    exchange_chain.reverse.flat_map { |order| chain_refund_tenders(order) }
  end

  def refund_reversals
    return super unless chain_refund?

    exchange_chain.reverse.flat_map { |order| chain_refund_reversals(order) }
  end

  protected

  # DB-only work first (reversals, then cash/check/pass refunds), card refunds
  # last, so a gateway failure rolls back everything in Order#refund!'s
  # transaction before any further card is touched.
  def refund_payments!(refund_note)
    return super unless chain_refund?

    tenders = refund_tenders
    refund_reversals.each { |payment| reverse_for_chain_refund!(payment) }
    cards, others = tenders.partition { |payment| payment.is_a?(CreditCardPayment) }
    others.each { |payment| payment.refund!(nil, refund_note) }
    cards.each do |card|
      card.refund!(nil, refund_note, idempotency_key: "#{uuid}-chain-refund-#{card.id}")
    end
  end

  # Any order of the chain, or an order it is being exchanged for, part-way
  # through an exchange. Statuses come from the database, so Order#refund!
  # (+lock: true+) sees an exchange begun after the order was loaded and holds
  # the rows until it commits.
  def exchange_state_refund_blockers(lock: false)
    rows = [Order.where(id: exchange_chain.map(&:id)).order(:id), exchange_successors.order(:id)]
    rows = rows.map(&:lock) if lock
    rows.flat_map { |scope| scope.pluck(:id, :status) }.uniq
        .select { |_order_id, status| MID_EXCHANGE_STATUSES.include?(status) }
        .map { |order_id, status| "Order ##{order_id} is part-way through an exchange (#{status})." }
  end

  private

  def chain_refund?
    exchange_source.present? && !exchange_successors.exists? && branched_chain_blockers.empty?
  end

  # An earlier order of the chain whose credit also went to an order outside
  # the chain: a split of an exchanged order (the split orders copy its
  # exchange_source_id) or an exchange left part-way. Settling the chain would
  # refund credit the other order still holds.
  def branched_chain_blockers
    newer_by_older = exchange_chain.each_cons(2).to_h { |newer, older| [older.id, newer.id] }
    return [] if newer_by_older.empty?

    TicketOrder.where(exchange_source_id: newer_by_older.keys).where.not(status: Order::CANCELED)
               .order(:id).pluck(:exchange_source_id, :id)
               .reject { |source_id, order_id| newer_by_older[source_id] == order_id }
               .map do |source_id, order_id|
                 "Order ##{source_id}'s exchange credit also went to order ##{order_id}, " \
                   'so a refund cannot settle the exchange chain.'
               end
  end

  # Orders this one was (or is being) exchanged for. An abandoned exchange is
  # destroyed; a cancelled one no longer holds the credit.
  def exchange_successors
    return TicketOrder.none if id.nil?

    TicketOrder.where(exchange_source_id: id).where.not(status: Order::CANCELED)
  end

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
        reversed_ids.exclude?(payment.id) && !settles_nothing?(payment) && !offsets_kept_tender?(payment)
    end
  end

  # A $0 offset or credit with no tickets: there is nothing to reverse.
  def settles_nothing?(payment)
    payment.amount.zero? && payment.number_of_tickets.to_i.zero?
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
