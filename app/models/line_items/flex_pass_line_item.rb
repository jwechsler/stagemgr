class FlexPassLineItem < LineItem
  
  belongs_to :flex_pass_offer, inverse_of: :flex_pass_line_items
  has_one :flex_pass, dependent: :destroy, inverse_of: :flex_pass_line_item
  belongs_to :flex_pass_order, :foreign_key => :order_id, inverse_of: :flex_pass_line_item
  before_save :ensure_flex_pass

  def price
    self.flex_pass_offer.price
  end

  def total
    price * ticket_count
  end

  def ticket_count
    1
  end
  
  def to_s
    "#{self.ticket_count} #{self.flex_pass_offer.name}"
  end

  private
  def ensure_flex_pass
    self.build_flex_pass(:flex_pass_offer=>self.flex_pass_offer,:order=>self.order,:address=>self.order.address) if self.flex_pass.nil?
  end

end
