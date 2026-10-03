class CurrencyPayment < Payment
  # Returns funds for a partial refund recorded by +refund_payment+ (a
  # RefundPayment on the same order). Cash and check are record-only: the box
  # office hands the money back. CreditCardPayment overrides this to call the
  # gateway.
  def return_funds!(_refund_payment); end

  # What is still on this payment: its amount less the partial refunds
  # (RefundPayment, pinned by type: see Payment STI scopes) already returned
  # against it by an exchange-and-refund.
  def refundable_amount
    return amount if id.nil?

    amount + Payment.where(type: 'RefundPayment', payment_id: id).sum(:amount)
  end

  # A full refund returns only what an exchange-and-refund has not already.
  def create_refund_payment(cc_number = nil, note = nil)
    refund_payment = super
    refund_payment.amount = 0.0 - refundable_amount
    refund_payment
  end

  protected

  def create_refund_payment?
    refundable_amount > 0
  end
end
