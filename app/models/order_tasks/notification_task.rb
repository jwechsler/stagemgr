class NotificationTask < OrderTask
  def cancel_with_order?
    false
  end

  def execute!
    if self.notifications.blank? || attempts > 8
      return false
    end
    result = true
    begin
      self.notifications.split(',').each { |address|
        NotificationMailer.send(self.method_symbol,self.order,address).deliver
      }

    rescue => detail
      result = false
      self.result = detail.message + '\n' + detail.backtrace.join("\n")
    end
    return result
  end
end
