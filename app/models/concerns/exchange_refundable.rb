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

  def prepare_exchange_from(original_order)
    self.exchange_source = original_order
    self.address = original_order.address
    self.status = Order::EXCHANGING
    exchange_source.status = Order::RELEASING
  end

  # Plain exchange: Carryover write-off or a new charge for the difference.
  # Refund exchange: the offsets were already netted, so any remainder is a bug.
  def settle_exchange_difference!(difference, refund:)
    if refund
      raise RefundNotPossible, "Exchange did not net to zero ($#{format('%.2f', difference)})" unless difference.zero?
    elsif difference.negative?
      payments << PriceOverridePayment.new(amount: difference, order: self,
                                           source_payment_type: exchange_source.payment_type)
    elsif difference.positive?
      create_proper_payment_in_amount_of!(difference)
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
