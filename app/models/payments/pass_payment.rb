class PassPayment < Payment

  def new_exchange_offset_payment
    offset_payment = super
    offset_payment.number_of_tickets = 0-self.number_of_tickets
    offset_payment
  end

  def create_refund_payment(cc_number = nil, note = nil)
    refund_payment = super
    refund_payment.number_of_tickets = 0 - refund_payment.number_of_tickets
    refund_payment
  end

end
