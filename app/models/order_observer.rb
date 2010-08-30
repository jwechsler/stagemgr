class OrderObserver < ActiveRecord::Observer
  observe Order
  
  def after_create(order)
    Notifier.deliver_order_notification(order)
    
  end
end