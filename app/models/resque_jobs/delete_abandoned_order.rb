class DeleteAbandonedOrder
  @queue = :maintenance

  def self.perform(order_id)
    o = Order.find(order_id)
    o.destroy if o.transitory?
  end

end
