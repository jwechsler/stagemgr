class SendFlexPassReminders
  @queue = :notification

  def self.perform
    email = Rails.configuration.x.email_address['flex_pass_notifications']

    if email.present?
      flex_pass_orders = FlexPassOrder.where(status: Order::PROCESSED)
      OrderMailer.send(:flex_pass_pending_reminder, flex_pass_orders).deliver
    end
    nil
  end
end
