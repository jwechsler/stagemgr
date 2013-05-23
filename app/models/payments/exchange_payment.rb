class ExchangePayment < Payment

  def receipt_description
    unless self.payment_id.nil?
      source_payment = "Exchg ##{Payment.find(self.payment_id).order_id}"
    else
      source_payment = "Exchg"
    end
    source_payment
  end

end
