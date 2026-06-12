class UpdateRecurringProfile
  @queue = :maintenance

  def self.perform(recurring_order_id)
    order = Order.find(recurring_order_id)
    order.recurring_profile.update_from_profile
    order.recurring_profile.save!
  rescue ActiveRecord::RecordNotFound
    Rails.logger.info("Could not locate order ##{recurring_order_id} to update payments for recurring profile")
  end
end
