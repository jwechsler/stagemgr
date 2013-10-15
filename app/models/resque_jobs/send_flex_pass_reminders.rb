class SendFlexPassReminders
  @queue = :notification

  def perform
    email = $EMAIL_ADDRESS['flex_pass_notifications']

    unless email.blank?
      flex_pass_orders = FlexPassOrder.find_all_by_status(Order::PROCESSED)
      OrderMailer.send(:flex_pass_pending_reminder, flex_pass_orders).deliver
    end
  end

end
