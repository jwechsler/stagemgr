class NotificationTask < OrderTask
  def cancel_with_order?
    false
  end

  def execute!
    return false if notifications.blank? || attempts > 8

    result = true
    begin
      notifications.split(',').each do |address|
        NotificationMailer.send(method_symbol, order, address).deliver
      end
    rescue StandardError => e
      result = false
      self.result = e.message + '\n' + e.backtrace.join("\n")
    end
    result
  end
end
