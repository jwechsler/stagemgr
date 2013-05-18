class PassPayment < Payment

  def create_exchange_offset_payment
    offset_payment = self.dup
    offset_payment.amount = -1*self.amount
    offset_payment.note = self.order.description
    offset_payment.order_id = nil
    offset_payment.payment_id = self.id
    offset_payment
  end

end
