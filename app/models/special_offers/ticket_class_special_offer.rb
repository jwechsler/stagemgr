class TicketClassSpecialOffer < SpecialOffer
  def apply_to_order(order)
    new_items, old_items = modified_line_items_in_order(order)
    new_items.each { |li| order.ticket_line_items << li }
    old_items.each { |li| order.ticket_line_items.delete(li) }
    order.adjust_seating_to_match_ticket_line_items(new_items, old_items)
    self
  end

  def modified_line_items_in_order(order)
    ticket_class = TicketClass.where('production_id = ? and class_code = ?', order.performance.production.id,
                                     change_ticket_class_code).first
    if ticket_class.nil?
      errors.add(:special_offer_code, 'is not applicable to this order')
      ticket_line_ids = []
    else
      ticket_line_ids = applicable_line_items(order).map { |l| l.id }
    end
    new_items = []
    old_items = []
    order.ticket_line_items.select { |li| ticket_line_ids.include?(li.id) }.each do |li|
      new_item = TicketLineItem.new(order_id: order.id,
                                    ticket_class: ticket_class,
                                    ticket_count: li.ticket_count,
                                    price_override: li.price_override)
      new_items << new_item
      old_items << li
    end
    [new_items, old_items]
  end

  def calculate_discount(_order)
    0.0
  end

  def to_s
    "Use #{change_ticket_class_code} on #{super}"
  end
end
