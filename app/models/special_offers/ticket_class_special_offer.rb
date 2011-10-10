class TicketClassSpecialOffer < SpecialOffer

  validates_presence_of :use_ticket_class_code

  def calculate_discount(order)
    self.applicable_line_items(order).map{|li|li.total}.sum * self.amount/-100
  end
  
  def to_s
    ""
  end
end
