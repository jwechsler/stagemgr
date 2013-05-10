class CashPaymentType < CurrencyPaymentType

  def currency?
    true
  end

  def create_payment!(amount, order, payment_details={})
    new_payment = CashPayment.new(:amount => amount)
  end

  def payment_classes
    super + [CashPayment.class]
  end

end
