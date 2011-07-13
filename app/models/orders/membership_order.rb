class MembershipOrder < Order

  has_many :membership_line_items, :foreign_key=>:order_id
  accepts_nested_attributes_for :membership_line_items
  validates_associated :membership_line_items

  def performance_code()
    "MEMBERSHIP"
  end

  def ticketing_fee
    BigDecimal.new("0",2)
  end

  def ticket_quantity
    BigDecimal.new("0",2)
  end


  def set_membership_offer(offer)
    li = MembershipLineItem.create(:membership_offer=>offer, :address=>self.address)

    self.membership_line_items << li
  end

  def membership
    if (!self.membership_line_items.first.nil?)
      self.membership_line_items.first.membership
    else
      nil
    end
  end

  def valid_payment_types_for(current_user)
    valid_payment_types = super(current_user)
    valid_payment_types.delete(Order::FLEX_PASS)
    valid_payment_types.delete(Order::MEMBERSHIP)
    valid_payment_types
  end

  def link_to_address_of_record
    super
    self.membership_line_items.each { |li| li.membership.address = self.address}
  end

  def set_defaults
    super
    self.membership_line_items.each { |di| di.order=self
                                           di.membership.address = self.address if !di.membership.nil? }
  end

  protected
  def unique_line_items(reload_line_items=false)
    (super.unique_line_items(reload_line_items) + self.recurring_line_items(reload_line_items)).uniq
  end

end