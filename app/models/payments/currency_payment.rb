class CurrencyPayment < Payment

  def create_exchange_offset_payment
    ExchangePayment.new(:amount => -1*self.amount, :note => self.order.description, :payment_id=>self.id)
  end

end
