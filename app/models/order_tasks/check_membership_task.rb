class CheckMembershipTask < OrderTask
  protected

  def execute!
    membership = self.order.membership
    if membership.blank? || attempts > 12
      return false
    end

    result = false

      if membership.is_active? || membership.is_pending?
        membership.update_from_profile
        if membership.number_cycles_completed_changed? && membership.is_active?
          membership.save!
          new_payment = self.order.create_recurring_payment
          self.order.tasks << CheckMembershipTask.new(:execute_at=>membership.next_billing_date + 1.day)
          self.order.payments << new_payment
          new_payment.note = "Automatic payment created by membership check task"
          self.order.save!
          result = true
        end
      end

    result
  end
end