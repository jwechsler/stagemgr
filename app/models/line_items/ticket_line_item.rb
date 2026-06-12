class TicketLineItem < LineItem
  belongs_to :ticket_order, foreign_key: :order_id, inverse_of: :ticket_line_items
  belongs_to :ticket_class, inverse_of: :ticket_line_items
  belongs_to :seat_assignment, optional: true, inverse_of: :ticket_line_item

  validates :ticket_count, presence: true

  before_validation :assign_from_attr_accessors
  before_save :check_price_override

  validates :price_override, numericality: { allow_nil: true }

  def ticket_class_allocation_available?
    return if order.nil? || order.performance_id.nil?

    TicketClassAllocation.where(ticket_class_id: id,
                                performance_id: performance.id).sum(:ticket_limit)
  end

  def price
    price_override || ticket_class.try(:ticket_price) || BigDecimal('0')
  end

  def refund!
    if ticket_count > 0
      refund_lineitem = dup
      refund_lineitem.ticket_count = refund_lineitem.ticket_count * -1
      refund_lineitem.ticket_class = ticket_class
      # The negative-count reversing entry is an accounting record, not a seat
      # owner. Clear the FK so the 1:1 uniqueness index isn't violated.
      refund_lineitem.seat_assignment_id = nil
      [refund_lineitem]
    else
      []
    end
  end

  def total
    price * (ticket_count || 0)
  end

  def ticket?
    true
  end

  def to_s
    "#{ticket_count} #{ticket_class.class_code}"
  end

  def royalty_price
    ticket_class.try(:royalty_price) || BigDecimal('0')
  end

  def royalty_total
    rp = royalty_price
    if generated_from_split? && price_override && ticket_class.ticket_price > 0
      ratio = price_override / ticket_class.ticket_price
      (rp * ratio * (ticket_count || 0)).round(2)
    else
      rp * (ticket_count || 0)
    end
  end

  def ticketing_fee
    ticket_class.ticketing_fee * ticket_count
  end

  def check_price_override
    return unless !generated_from_split? && (price_override.eql?(0) || !ticket_class.ticket_type.eql?('Donation'))

    self.price_override = nil
  end

  delegate :complimentary?, to: :ticket_class

  private

  def assign_from_attr_accessors
    return unless order && order.performance && order.performance.ticket_classes.count > 0

    return unless @ticket_class_code

    self.ticket_class = order.performance.ticket_classes.find_by_class_code @ticket_class_code
  end
end
