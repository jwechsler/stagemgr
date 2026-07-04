class OutreachTask < OrderTask
  protected

  def execute!
    return false if order.address.email.blank? || attempts > 8

    result = true
    begin
      OrderMailer.send(method_symbol, order).deliver_now unless order.address.email.nil?
    rescue StandardError => e
      result = false
      self.result = e.message + '\n' + e.backtrace.join("\n")
    end
    result
  end
end
