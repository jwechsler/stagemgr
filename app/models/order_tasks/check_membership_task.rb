class CheckMembershipTask < OrderTask
 protected

  def execute!
    membership = self.order.membership
    if membership.blank? || attempts > 12
      return false
    end

    membership.update_from_profile!

    result = !membership.is_pending?
    if membership.is_active?
      self.order.tasks << CheckMembershipTask.new(:execute_at=>membership.next_billing_date + 3.hours)
      new_payment = self.order.create_proper_payment_in_amount_of!(0)
      new_payment.note = "Automatic payment created by membership check task"
      self.order.save!
    end
    result
  end
end