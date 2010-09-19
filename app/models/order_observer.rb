class OrderObserver < ActiveRecord::Observer
  observe Order
  
  def after_save(order)
    if order.status == Order::PROCESSED && order.email_confirmation == 1 && !order.address.email.blank?
      Notifier.deliver_order_notification(order)
    end
  end
  
end