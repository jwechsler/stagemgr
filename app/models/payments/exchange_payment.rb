class ExchangePayment < Payment

  def receipt_description
    source_payment = "Exchange from order #{Payment.find(self.payment_id).order_id}"
  end

end
