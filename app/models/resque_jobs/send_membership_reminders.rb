class SendMembershipReminders
  @queue = :notification

  def self.perform
    email = $EMAIL_ADDRESS['membership_notifications']

    unless email.blank?
      membership_orders = MembershipOrder.where(status:Order::PROCESSED)
      OrderMailer.send(:membership_pending_reminder, membership_orders).deliver
    end
  end

end
