class OutreachTask < OrderTask

  protected

  def execute!
    if self.order.address.email.blank? || attempts > 8
      return false
    end
    result = true
    begin
      OrderMailer.send(self.method_symbol,self.order).deliver_now if !self.order.address.email.nil?
    rescue => detail
      result = false
      self.result = detail.message + '\n' + detail.backtrace.join("\n")
    end
    return result
  end
end
