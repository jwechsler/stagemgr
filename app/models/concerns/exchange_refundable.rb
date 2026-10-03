# Exchange settlement for TicketOrder. A plain exchange writes a down-price
# difference off as a Carryover (or charges the card for an increase);
# exchange-and-refund returns the difference to the original order's cash,
# check or card payments as RefundPayments, with the gateway call as the final
# step before commit. The shared offset/credit mechanics live in
# TicketOrder#begin_exchange!, which calls the helpers below.
module ExchangeRefundable
  extend ActiveSupport::Concern

  # Raised when the price difference cannot be returned: nothing is owed, or
  # the original was not paid by cash, check or card.
  class RefundNotPossible < StandardError; end

  # Raised, before any row is written, when the original can no longer be
  # exchanged: another exchange or a refund got to it first.
  class ExchangeNotPossible < StandardError; end

  # True after #exchange_and_refund_from! when the new order cost exactly what
  # the original did: the exchange went through and nothing was refunded.
  def refund_not_needed?
    @refund_not_needed == true
  end

  # Same exchange as #exchange_and_process_from!, but the price difference goes
  # back to the original payments instead of being written off. An even swap
  # has no difference, so it is exchanged with no refund (#refund_not_needed?). The gateway
  # call is the LAST step so a card failure rolls back every row: the new
  # order, the offsets, the refunds and the original's status.
  def exchange_and_refund_from!(original_order)
    Order.transaction do
      refunds = begin_exchange!(original_order, refund: true)
      transition_exchanging_to_processed!
      refunds.each_with_index { |refund, index| process_exchange_refund!(refund, index) }
    end
  end

  private

  # First statement of an exchange's transaction: locks the original's row
  # (only that row; see RefundEligibility#locked_refund_blockers for the lock
  # order) and re-reads it, so concurrent exchanges and refunds of one order
  # serialize and the loser is refused. Reads the status without reloading
  # +original_order+, which would drop the payments the exchange has built.
  # The original stays PROCESSED on disk until the exchange commits it as
  # EXCHANGED (RELEASING is in memory only), so a sold status is required both
  # when the exchange begins and when it completes.
  def lock_exchange_source!(original_order)
    current = Order.where(id: original_order.id).lock.pick(:status)
    unless TicketOrderMergeable::SOLD_STATUSES.include?(current)
      raise ExchangeNotPossible, "Order ##{original_order.id} is #{current} and can no longer be exchanged."
    end

    other = TicketOrder.where(exchange_source_id: original_order.id, status: Order::EXCHANGING)
                       .where.not(id: id).pick(:id)
    return if other.nil?

    raise ExchangeNotPossible, "Order ##{original_order.id} is already being exchanged for order ##{other}."
  end

  def prepare_exchange_from(original_order)
    self.exchange_source = original_order
    self.address = original_order.address
    self.status = Order::EXCHANGING
    exchange_source.status = Order::RELEASING
  end

  # Plain exchange: Carryover write-off or a new charge for the difference.
  # Refund exchange: the offsets were already netted, so any remainder is a bug.
  # A charge is only built (and validated) here; transition_exchanging_to_processed!
  # charges it once every check has passed.
  def settle_exchange_difference!(difference, refund:)
    if refund
      raise RefundNotPossible, "Exchange did not net to zero ($#{format('%.2f', difference)})" unless difference.zero?
    elsif difference.negative?
      payments << PriceOverridePayment.new(amount: difference, order: self,
                                           source_payment_type: exchange_source.payment_type)
    elsif difference.positive?
      @exchange_difference_payment = payment_type.build_uncharged_payment(difference, self)
      raise ActiveRecord::RecordInvalid, @exchange_difference_payment if @exchange_difference_payment.invalid?
    end
  end

  # Puts the uncharged difference payment, if any, onto the reloaded payments
  # and runs the pre-charge checks, raising if the order is not ready to charge.
  def checked_exchange_difference_payment
    payment = @exchange_difference_payment
    return if payment.nil?

    @exchange_difference_payment = nil
    association(:payments).add_to_target(payment)
    raise ActiveRecord::RecordInvalid, self unless ready_to_charge?

    payment
  end

  # The last steps of transition_exchanging_to_processed!: a charge that
  # succeeds is refunded if the save after it fails.
  def charge_difference_and_save!(payment)
    reversing_charges_on_failure do
      charge_proper_payment!(payment) unless payment.nil?
      save!
    end
  end

  def process_exchange_refund!(refund, index)
    refund.note = "Refund for exchange to order ##{id}"
    refund.idempotency_key = "#{uuid}-refund-#{index}" if uuid.present?
    refund.process!
  end

  # Shrinks the largest eligible offsets by the amount owed back and builds one
  # RefundPayment per shrunk offset, so the credits mirror total_due exactly.
  # Capping each portion at the offset's magnitude means a card is never
  # refunded more than its (fee-netted) charge.
  def allocate_exchange_refunds(offsets)
    refund_total = -(total_due + offsets.sum(&:amount))
    if refund_total.zero?
      @refund_not_needed = true
      return []
    end
    raise RefundNotPossible, costs_more_message(-refund_total) if refund_total.negative?

    remaining = refund_total
    refunds = []
    eligible_refund_offsets(offsets).each do |offset|
      break unless remaining.positive?

      portion = [remaining, offset.amount.abs].min
      offset.amount += portion
      remaining -= portion
      refunds << build_refund_payment(offset.source_payment, portion)
    end
    remaining = allocate_chain_refunds(offsets, remaining, refunds) if remaining.positive?
    raise RefundNotPossible, uncoverable_refund_message(refund_total, remaining) if remaining.positive?

    refunds
  end

  # Rows an exchange-and-refund writes on earlier orders of the chain, saved by
  # begin_exchange! after the original's own rows (#allocate_chain_refunds).
  def chained_refund_rows
    @chained_refund_rows ||= []
  end

  # Exchange credit on the original came from the orders it was exchanged
  # from, so what its own payments cannot cover goes back to a cash, check or
  # card payment on one of those, nearest order first. Per portion: the
  # original's credit offset shrinks as for its own tenders; an ExchangePayment
  # pair moves the credit back (-portion on the original against its credit,
  # +portion on the tender's order against the tender's offset); the
  # RefundPayment sits on the tender's order. Every order still nets to zero,
  # and a later chain refund (ExchangeChainRefundable) reverses the pair along
  # with the other exchange rows.
  def allocate_chain_refunds(offsets, remaining, refunds)
    credit_offsets = offsets.select { |offset| offset.amount.negative? && offset.source_payment.is_a?(ExchangePayment) }
    return remaining if credit_offsets.empty? || exchange_source.branched_chain_blockers.any?

    available = earlier_chain_tenders.index_with(&:refundable_amount)
    credit_offsets.each do |offset|
      available.each_key do |tender|
        portion = [remaining, offset.amount.abs, available[tender]].min
        next unless portion.positive?

        offset.amount += portion
        remaining -= portion
        available[tender] -= portion
        refunds << chain_refund_for(offset, tender, portion)
      end
    end
    remaining
  end

  # Cash, check and card payments with money left on the orders the original
  # was exchanged from, nearest order first.
  def earlier_chain_tenders
    exchange_source.exchange_chain.drop(1).flat_map do |order|
      order.payments.select do |payment|
        payment.is_a?(CurrencyPayment) && payment.amount.positive? && payment.refundable? &&
          payment.refundable_amount.positive?
      end
    end
  end

  def chain_refund_for(credit_offset, tender, portion)
    tender_order = tender.order
    chained_refund_rows.push(
      ExchangePayment.new(amount: -portion, order: exchange_source, source_payment: credit_offset.source_payment,
                          payment_type: tender.payment_type,
                          note: "Exchange credit returned to order ##{tender_order.id} for refund"),
      ExchangePayment.new(amount: portion, order: tender_order, source_payment: tender_offset(tender),
                          payment_type: tender.payment_type,
                          note: "Exchange credit from order ##{exchange_source.id} returned for refund")
    )
    build_refund_payment(tender, portion, order: tender_order).tap { |refund| chained_refund_rows << refund }
  end

  # The offset written when the tender's order was exchanged onward.
  def tender_offset(tender)
    tender.order.payments.find do |payment|
      payment.is_a?(ExchangePayment) && payment.payment_id == tender.id && payment.amount.negative?
    end
  end

  # Offsets of cash, check or card payments, largest first. Positive offsets
  # (from an earlier negative payment on the original) are never refundable.
  def eligible_refund_offsets(offsets)
    offsets.select { |offset| offset.amount.negative? && offset.source_payment.is_a?(CurrencyPayment) }
           .sort_by(&:amount)
  end

  def build_refund_payment(source_payment, portion, order: exchange_source)
    RefundPayment.new(amount: -portion, order: order, source_payment: source_payment,
                      payment_type: source_payment.payment_type, note: 'Exchange refund')
  end

  def costs_more_message(increase)
    "Nothing to refund: the new order costs $#{format('%.2f', increase)} more than the original. " \
      'Use Exchange Order to charge the difference.'
  end

  def uncoverable_refund_message(refund_total, remaining)
    covered = CurrencyUtils.float_to_currency_decimal(refund_total - remaining)
    "Only $#{format('%.2f', covered)} of the $#{format('%.2f', refund_total)} difference was paid by cash, check or card " \
      "on order ##{exchange_source.id} or the orders it was exchanged from, and can be refunded."
  end
end
