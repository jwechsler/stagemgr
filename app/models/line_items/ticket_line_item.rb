class TicketLineItem < LineItem
  belongs_to :ticket_order, :foreign_key => :order_id
  belongs_to :ticket_class

  validates_presence_of :ticket_class, :ticket_count

  validates_each :price_override do |record, attr, value|
    if record.ticket_class && record.ticket_class.ticket_type != 'Donation' && !record.generated_from_split?
      record.errors.add attr, "cannot be used on ticket class type #{record.ticket_class.ticket_type}" unless value.nil?
    end
  end

  validates_numericality_of :price_override, :allow_nil => true

  def ticket_class_allocation_available?
    unless self.order.nil? || self.order.performance_id.nil?
      number_available = TicketClassAllocation.where(ticket_class_id:self.id, performance_id:performance.id).sum(:ticket_limit)
    end

  end

  def price
    self.price_override || self.ticket_class.try(:ticket_price) || BigDecimal(0,2)
  end

  def refund!
    if self.ticket_count > 0
      refund_lineitem = self.dup
      refund_lineitem.ticket_count = refund_lineitem.ticket_count*-1
      refund_lineitem.ticket_class = self.ticket_class
      [refund_lineitem]
    else
      []
    end

  end

  def total
    price * (self.ticket_count || 0)
  end

  def ticket?
    return true;
  end

  def to_s
    "#{ticket_count} #{ticket_class.class_code}"
  end

  def ticketing_fee
    self.ticket_class.ticketing_fee * self.ticket_count
  end

end