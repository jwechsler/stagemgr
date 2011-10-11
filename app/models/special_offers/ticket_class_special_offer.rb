class TicketClassSpecialOffer < SpecialOffer

  def apply_to_order(order)
    ticket_class = TicketClass.where("production_id = ? and class_code = ?",order.performance.production.id,self.change_ticket_class_code).first
    raise "Non applicable offer to this order" if ticket_class.nil?
    ticket_line_items = self.applicable_line_items(order)
    ticket_line_items.each {|li| li.ticket_class = ticket_class }
    self
  end

  def calculate_discount(order)
    return 0.0
  end

  def to_s
    "Use #{self.change_ticket_class_code} / #{super}"
  end
end
