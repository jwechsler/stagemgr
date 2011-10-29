class ExchangePayment < Payment

  def receipt_description
    source_payment = "Exchg ##{Payment.find(self.payment_id).order_id}"
  end

end
