class ExchangePayment < Payment

  def receipt_description
    unless self.order.nil? || self.order.exchange_source.nil?
      source_payment = "Exchg ##{Payment.find(self.order.exchange_source.id)}"
    else
      source_payment = "Exchg"
    end
    source_payment
  end

end
