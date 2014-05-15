class DeleteAbandonedOrder
  @queue = :maintenance

  def self.perform(order_id)
  	Authorization.ignore_access_control(true)
    begin
      o = Order.find(order_id)
      o.destroy if o.transitory?
    rescue ActiveRecord::RecordNotFound
    ensure
    	Authorization.ignore_access_control(false)
    end
  end

end
