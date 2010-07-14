class TicketLineItem < LineItem
  validates_each :ticket_count do |record, attr, value|
    unless record.ticket_class.nil? || record.order.nil? || record.order.performance.nil? || value.nil?
      record.errors.add attr, 'is more than the number left'  if value > record.ticket_class.number_left(record.order.performance)
    end
  end

  validates_each :price_override do |record, attr, value|
    if record.ticket_class && record.ticket_class.ticket_type != 'Donation'
      record.errors.add attr, "cannot be used on ticket class type #{record.ticket_class.ticket_type}" unless value.nil?
    end
  end
  
  validates_numericality_of :price_override, :allow_nil=>true

  def price
    (self.price_override || self.ticket_class.try(:ticket_price)) || 0
  end
  
  def refund!
    self.order.line_items.create!(self.attributes.merge(:ticket_count=>self.ticket_count*-1))
  end

  def total
    price * (self.ticket_count || 0)
  end

end