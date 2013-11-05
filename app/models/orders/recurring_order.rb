class RecurringOrder < Order

  has_many :recurring_payments, :foreign_key=>:order_id

  def suspend!
    raise "Recurringorder.suspend not yet implemented!"
  end

  def cancel!
    raise "RecurringOrder.cancel not yet implemeneted"
  end

end
