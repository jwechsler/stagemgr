class CreditCardPaymentType < CurrencyPaymentType
  # A $0 card order is recorded as a $0 cash payment. A real card payment is
  # marked awaiting_charge so it validates as it will once charged and cannot
  # be saved until #charge! has run the gateway purchase.
  def build_uncharged_payment(amount, order, _payment_details = {})
    return CashPaymentType.first.build_uncharged_payment(0, order) if amount == 0

    CreditCardPayment.new(
      amount: amount,
      address: order.address,
      order: order,
      card_number: order.credit_card_number,
      card_expiration_month: order.credit_card_expiration_month,
      card_expiration_year: order.credit_card_expiration_year,
      card_type: order.credit_card_type,
      card_verification_number: order.credit_card_verification_number,
      confirmation_code: order.credit_card_confirmation_code,
      ip_address: order.ip_address,
      payment_type: self,
      awaiting_charge: true
    )
  end

  # The gateway purchase (or, for the $0 cash stand-in, a plain save).
  def charge!(payment, _order)
    payment.process!
  end

  def payment_classes
    super + [CreditCardPayment.class]
  end
end
