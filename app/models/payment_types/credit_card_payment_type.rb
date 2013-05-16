class CreditCardPaymentType < CurrencyPaymentType

  def create_payment!(amount, order, payment_details={})

    if (amount != 0) then

      new_payment = CreditCardPayment.new(
        :amount => amount,
        :address => order.address,
        :order => order,
        :card_number => order.credit_card_number,
        :card_expiration_month => order.credit_card_expiration_month,
        :card_expiration_year => order.credit_card_expiration_year,
        :card_type => order.credit_card_type,
        :card_verification_number => order.credit_card_verification_number,
        :confirmation_code => order.credit_card_confirmation_code,
        :ip_address => order.ip_address,
        :payment_type=>self
      )
    else
      new_payment = CashPaymentType.first.create_payment!(0, order)
    end

    new_payment.process!

    new_payment

  end

  def payment_classes
    super + [CreditCardPayment.class]
  end


end
