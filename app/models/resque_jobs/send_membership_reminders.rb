class SendMembershipReminders
  @queue = :notification

  def self.perform
    email = $EMAIL_ADDRESS['membership_notifications']

    if email.present?
      membership_orders = MembershipOrder.where(status: Order::PROCESSED)
      OrderMailer.send(:membership_pending_reminder, membership_orders).deliver
    end
    nil
  end
end
