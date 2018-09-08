class DeleteAbandonedOrders
  @queue = :maintenance

  def self.perform
    orders = Order.where("status = :status and updated_at < :time_window",
      status: Order::PROCESSING, time_window: Time.now-8.minutes)
    orders.each do |o|
      o.destroy
    end
  end

end
