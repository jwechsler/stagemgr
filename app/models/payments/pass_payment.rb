class PassPayment < Payment

  def create_exchange_offset_payment
    offset_payment = self.dup
    offset_payment.amount = -1*self.amount
    offset_payment.note = self.order.description
    offset_payment.order_id = nil
    offset_payment.payment_id = self.id
    offset_payment
  end

    def create_refund_payment(cc_number = nil, note = nil)
      refund_payment = super
      refund_payment.number_of_tickets = 0 - refund_payment.number_of_tickets
      refund_payment
  end

end
