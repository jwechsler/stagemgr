# A partial refund issued during an exchange. It is recorded on the ORIGINAL
# order and points (via payment_id / source_payment) at the CurrencyPayment
# whose funds are returned. Card refunds hit the gateway in #process!;
# cash and check refunds are record-only.
class RefundPayment < Payment
  CENTS_PER_DOLLAR = 100

  # Set by the exchange before #process! so a retried submission replays the
  # same Stripe refund instead of issuing a second one.
  attr_accessor :idempotency_key

  validates :source_payment, presence: true
  validates :amount, numericality: { less_than: 0 }
  validate :source_is_currency_payment

  # Amount is a decimal(8,2); round through BigDecimal so 0.29 becomes 29, not 28.
  def refund_cents
    (amount.abs * CENTS_PER_DOLLAR).round.to_i
  end

  # Final step of an exchange-and-refund. A gateway failure raises
  # CannotProcessPayment, which rolls back the whole exchange transaction.
  def process!(_order = nil)
    source_payment.return_funds!(self)
    super
  end

  def display_name
    "#{super} Refund"
  end

  def receipt_description
    'Refund'
  end

  # A committed refund is never silently dropped by cancellation or by the
  # abandoned-exchange cleanup (TicketOrder#reverse_source_exchange_payments).
  def can_cancel?
    false
  end

  private

  def source_is_currency_payment
    return if source_payment.is_a?(CurrencyPayment)

    errors.add(:source_payment, 'must be a cash, check or credit card payment')
  end
end
