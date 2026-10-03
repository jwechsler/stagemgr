# Whether Order#refund! may run, and what it returns. The refund page and
# Admin::RefundOrdersController both go by #refund_blockers, so the server
# refuses a refund the page would not offer. TicketOrder narrows the payment
# lists and adds the exchange-chain checks (ExchangeChainRefundable).
module RefundEligibility
  extend ActiveSupport::Concern

  # Raised by Order#refund! when, under the row locks, the order turns out to
  # be refunded already or mid-exchange (since the refund was checked).
  class RefundNotAllowed < StandardError; end

  # Payment kinds a refund knows how to return. Anything else with something
  # to refund (e.g. a positive Carryover outside a chain) blocks the refund.
  # Names, not classes, so Order loads without loading every payment class.
  REFUNDABLE_PAYMENT_CLASS_NAMES = %w[CreditCardPayment CashPayment CheckPayment ExternalPayment
                                      MembershipPayment FlexPassPayment].freeze

  # An order that reached one of these since it was loaded has passed its
  # value on (or never kept it). Other changes, e.g. PROCESSED -> FULFILLED
  # when its tickets print, still leave it refundable.
  # Literals: Order includes this module before it defines its status constants.
  GIVEN_UP_STATUSES = %w[Exchanged Split Canceled].freeze

  # Human-readable reasons this order can't be refunded now; empty when it can.
  def refund_blockers
    blockers = []
    blockers << "Order ##{id} can't be refunded while it is #{status}." unless refundable?
    unsupported = unsupported_refund_payments
    if unsupported.any?
      blockers << "Refunds don't handle #{unsupported.map { |payment| payment.display_name.strip }.uniq.to_sentence} payments."
    end
    blockers + exchange_state_refund_blockers
  end

  def refund_allowed?
    refund_blockers.empty?
  end

  def unsupported_refund_payments
    refund_tenders.reject { |payment| REFUNDABLE_PAYMENT_CLASS_NAMES.include?(payment.class.name) }
  end

  # The orders a refund of this one settles: just this order, except for a
  # TicketOrder at the end of an exchange chain (ExchangeChainRefundable).
  def exchange_chain
    [self]
  end

  # Payments Order#refund! returns, each on its own tender (card, cash, pass, ...).
  def refund_tenders
    payments.select(&:refundable?)
  end

  # Exchange credits, offsets and Carryovers a refund cancels with a
  # ReversalPayment instead of refunding. None outside an exchange chain.
  def refund_reversals
    []
  end

  protected

  # Re-read under row locks inside Order#refund!'s transaction: a refund
  # submitted twice waits for the first, then finds the order REFUNDED, and a
  # refund that lost a race to an exchange finds it EXCHANGED.
  #
  # Lock order, to avoid deadlocks: a refund locks every order of its chain in
  # one statement in ascending id, then the orders exchanged from it (always
  # newer, so higher ids). An exchange (ExchangeRefundable#lock_exchange_source!)
  # and Add to Order (TicketOrderAddition#prepare!) each lock a single order
  # row, first thing in their transaction.
  def locked_refund_blockers
    return [] if new_record?

    current = Order.where(id: exchange_chain.map(&:id)).order(:id).lock.pluck(:id, :status).to_h[id]
    blockers = []
    if current == Order::REFUNDED
      blockers << "Order ##{id} has already been refunded."
    elsif GIVEN_UP_STATUSES.include?(current) && current != status_in_database
      blockers << "Order ##{id} is now #{current}."
    end
    blockers + exchange_state_refund_blockers(lock: true)
  end

  # Reasons from the exchange state of the order's chain, read fresh from the
  # database; with +lock: true+, under row locks. None outside a TicketOrder.
  def exchange_state_refund_blockers(**)
    []
  end

  # The payment half of #refund!, inside its transaction.
  def refund_payments!(refund_note)
    refund_tenders.each { |payment| payment.refund!(nil, refund_note) }
  end
end
