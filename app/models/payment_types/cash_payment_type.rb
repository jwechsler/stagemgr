class CashPaymentType < CurrencyPaymentType
  def currency?
    true
  end

  def build_payment(amount, order, payment_details = {})
    new_payment = CashPayment.new(:amount => amount, :payment_type => self, :order => order)
  end

  def payment_classes
    super + [CashPayment.class]
  end
end
