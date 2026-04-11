class TicketLineItem < LineItem
  belongs_to :ticket_order, :foreign_key => :order_id, inverse_of: :ticket_line_items
  belongs_to :ticket_class, inverse_of: :ticket_line_items

  validates_presence_of :ticket_count

  before_validation :assign_from_attr_accessors
  before_save :check_price_override
  
  validates_numericality_of :price_override, :allow_nil => true

  def ticket_class_allocation_available?
    unless self.order.nil? || self.order.performance_id.nil?
      number_available = TicketClassAllocation.where(ticket_class_id:self.id, performance_id:performance.id).sum(:ticket_limit)
    end

  end

  def price
    self.price_override || self.ticket_class.try(:ticket_price) || BigDecimal('0')
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

  def royalty_price
    self.ticket_class.try(:royalty_price) || BigDecimal('0')
  end

  def royalty_total
    rp = royalty_price
    if generated_from_split? && price_override && ticket_class.ticket_price > 0
      ratio = price_override / ticket_class.ticket_price
      (rp * ratio * (self.ticket_count || 0)).round(2)
    else
      rp * (self.ticket_count || 0)
    end
  end

  def ticketing_fee
    self.ticket_class.ticketing_fee * self.ticket_count
  end

  def check_price_override
    self.price_override = nil if !self.generated_from_split? && (self.price_override.eql?(0) || !self.ticket_class.ticket_type.eql?('Donation'))
  end

  def complimentary?
    ticket_class.complimentary?
  end

  private
  def assign_from_attr_accessors
    return unless self.order && self.order.performance && self.order.performance.ticket_classes.count > 0
    self.ticket_class = self.order.performance.ticket_classes.find_by_class_code @ticket_class_code if @ticket_class_code
  end


end