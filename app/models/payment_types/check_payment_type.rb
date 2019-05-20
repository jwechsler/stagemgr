class CheckPaymentType < CurrencyPaymentType

def build_payment(amount, order, payment_details={})
    new_payment = CheckPayment.new(:amount => amount, :payment_type=>self, :order=>order)
    new_payment.note = "Check ##{order.check_number}"
    new_payment
  end

  def payment_classes
    super + [CheckPayment.class]
  end

end
