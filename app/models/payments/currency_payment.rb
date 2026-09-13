class CurrencyPayment < Payment
  # Returns funds for a partial refund recorded by +refund_payment+ (a
  # RefundPayment on the same order). Cash and check are record-only: the box
  # office hands the money back. CreditCardPayment overrides this to call the
  # gateway.
  def return_funds!(_refund_payment); end
end
