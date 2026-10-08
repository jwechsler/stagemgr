class DeleteAbandonedOrders
  @queue = :maintenance

  def self.perform
    orders = Order.where('status in (:status) and updated_at < :time_window',
                         status: [Order::NEW, Order::PROCESSING], time_window: Time.now - 8.minutes)
    orders.each do |o|
      next if o.destroy

      Rails.logger.warn("Could not delete abandoned order #{o.id}: #{o.errors.full_messages.to_sentence}")
    rescue RuntimeError => e
      Rails.logger.error("Could not delete abandonded order #{o.id}:")
      Rails.logger.error e.message
      e.backtrace.each { |line| Rails.logger.error line }
    end
  end
end
