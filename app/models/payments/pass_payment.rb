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

  def new_offset_payment(partial_amount = nil, partial_number_of_tickets = nil)
    new_payment = super(partial_amount, number_of_tickets)
    if partial_number_of_tickets.nil?
      new_payment.number_of_tickets = (0-new_payment.number_of_tickets)
    else
      new_payment.number_of_tickets = 0-[new_payment.number_of_tickets, partial_number_of_tickets].min
    end
    new_payment
  end

end
