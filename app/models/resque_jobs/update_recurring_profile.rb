class UpdateRecurringProfile
  @queue = :maintenance

  def self.perform(recurring_order_id)
    order = RecurringOrder.find(recurring_order_id)
    order.reconcile_to_payment_service

  end

end
