class OutreachTask < OrderTask

  protected

  def execute!
    if self.order.address.email.blank? || attempts > 2
      return false
    end
    OrderMailer.send(self.method_symbol,self.order).deliver if !self.order.address.email.nil?
    return true
  end
end