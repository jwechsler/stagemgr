class MembershipOrder < Order

  has_many :membership_line_items, :foreign_key=>:order_id
  accepts_nested_attributes_for :membership_line_items

  def performance_code()
    "MEMBERSHIP"
  end

  def ticketing_fee
    BigDecimal.new("0",2)
  end

  def ticket_quantity
    BigDecimal.new("0",2)
  end

  def add_membership_offer(offer)
    # code here
  end

  def add_payment(payment)
    # code here
  end

  def membership
    if (!self.membership_line_items.first.nil?)
      self.membership_line_items.first.membership
    else
      nil
    end
  end

  protected
  def unique_line_items(reload_line_items=false)
    (super.unique_line_items(reload_line_items) + self.recurring_line_items(reload_line_items)).uniq
  end
end