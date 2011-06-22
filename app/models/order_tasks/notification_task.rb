class NotificationTask < OrderTask

  def execute
    OrderMailer.send(self.method_symbol,self.order) if !self.order.address.email.nil?
  end
end