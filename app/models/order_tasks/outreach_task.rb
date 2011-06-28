class OutreachTask < OrderTask

  protected

  def execute!
    OrderMailer.send(self.method_symbol,self.order).deliver if !self.order.address.email.nil?
    return true
  end
end