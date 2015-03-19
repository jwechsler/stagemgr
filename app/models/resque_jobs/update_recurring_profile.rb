class UpdateRecurringProfile
  @queue = :maintenance

  def self.perform(recurring_order_id)
    begin
      order = Order.find(recurring_order_id)
      order.reconcile_to_payment_service
      order.queue_next_sanity_check unless order.membership.canceled?
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.info("Could not locate order ##{recurring_order_id} to update payments for recurring profile")
    end
  end

end
