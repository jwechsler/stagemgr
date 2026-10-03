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

  # Same exchange as #exchange_and_process_from!, but the price difference goes
  # back to the original payments instead of being written off. The gateway
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
    unless refund_total.positive?
      raise RefundNotPossible, 'Nothing to refund: the new order costs at least as much as the original. ' \
                               'Use Exchange Order instead.'
    end

    remaining = refund_total
    refunds = []
    eligible_refund_offsets(offsets).each do |offset|
      break unless remaining.positive?

      portion = [remaining, offset.amount.abs].min
      offset.amount += portion
      remaining -= portion
      refunds << build_refund_payment(offset.source_payment, portion)
    end
    raise RefundNotPossible, uncoverable_refund_message(refund_total, remaining) if remaining.positive?

    refunds
  end

  # Offsets of cash, check or card payments, largest first. Positive offsets
  # (from an earlier negative payment on the original) are never refundable.
  def eligible_refund_offsets(offsets)
    offsets.select { |offset| offset.amount.negative? && offset.source_payment.is_a?(CurrencyPayment) }
           .sort_by(&:amount)
  end

  def build_refund_payment(source_payment, portion)
    RefundPayment.new(amount: -portion, order: exchange_source, source_payment: source_payment,
                      payment_type: source_payment.payment_type, note: 'Exchange refund')
  end

  def uncoverable_refund_message(refund_total, remaining)
    covered = CurrencyUtils.float_to_currency_decimal(refund_total - remaining)
    "Only $#{format('%.2f', covered)} of the $#{format('%.2f', refund_total)} difference was paid by cash, check or card " \
      "on order ##{exchange_source.id} and can be refunded."
  end
end
