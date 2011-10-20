class ExchangePayment < Payment

  def receipt_description
    source_payment = Payment.find(self.payment_id).receipt_description
  end

end
