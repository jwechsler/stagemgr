class Notifier < ActionMailer::Base
  
  def order_notification(order)
    recipients order.address.email
    from       "boxoffice@theaterwit.org"
    subject    "Your ticket order for #{order.performance.production.name}"
    body       
  end

end
