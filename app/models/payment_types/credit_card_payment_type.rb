class CreditCardPaymentType < CurrencyPaymentType
  def build_payment(amount, order, _payment_details = {})
    new_payment = if amount == 0
                    CashPaymentType.first.build_payment(0, order)
                  else

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
                      payment_type: self
                    )
                  end

    new_payment.process!

    new_payment
  end

  def payment_classes
    super + [CreditCardPayment.class]
  end
end
