class TicketClassSpecialOffer < SpecialOffer
  def calculate_discount(order)
    self.applicable_line_items(order).map{|li|li.total}.sum * self.amount/-100
  end
  
  def to_s
    ""
  end
end
