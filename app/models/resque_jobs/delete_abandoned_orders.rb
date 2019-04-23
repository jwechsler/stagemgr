class DeleteAbandonedOrders
  @queue = :maintenance

  def self.perform
    orders = Order.where("status in (:status) and updated_at < :time_window",
      status: [Order::NEW, Order::PROCESSING], time_window: Time.now-8.minutes)
    orders.each do |o|
      begin
        o.destroy
      rescue RuntimeError => e
        Rails.logger.error("Could not delete abandonded order #{o.id}:")
        Rails.logger.error e.message
        e.backtrace.each { |line| Rails.logger.error line }
      end
    end
  end

end
