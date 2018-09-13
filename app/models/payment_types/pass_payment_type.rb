class PassPaymentType < PaymentType

  def self.applicable_price(regular_ticket_class, offer_ticket_class)
    return [regular_ticket_class.ticket_price, offer_ticket_class.ticket_price].min
  end

  def build_exchange_offset_payments(source_payments)
    Array.new
  end

end
