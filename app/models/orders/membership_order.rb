class MembershipOrder < Order

  accepts_nested_attributes_for :recurring_line_items

  def performance_code()
    "MEMBERSHIP"
  end

  def ticketing_fee
    BigDecimal.new("0",2)
  end

  def ticket_quantity
    BigDecimal.new("0",2)
  end

  protected
  def unique_line_items(reload_line_items=false)
    (super.unique_line_items(reload_line_items) + self.recurring_line_items(reload_line_items)).uniq
  end
end