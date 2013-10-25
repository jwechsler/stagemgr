class DeleteAbandonedOrder
  @queue = :maintenance

  def self.perform(order_id)
    begin
      o = Order.find(order_id)
      o.destroy if o.transitory?
    rescue ActiveRecord::RecordNotFound
    end
  end

end
