class CheckMembershipTask < OrderTask
  protected

  def execute!
    membership = self.order.membership
    if membership.blank? || attempts > 48
      return false
    end

    result = false

      membership.update_from_profile
      if membership.number_cycles_completed_changed? && membership.active?
        new_payment = self.order.create_recurring_payment("Created by membership check task")
        self.order.tasks << CheckMembershipTask.new(:execute_at=>membership.next_billing_date + 1.day)
        self.order.payments << new_payment
        self.order.save!
        result = true
      end
      membership.save!


    self.execute_at += 1.hours if !result

    result
  end
end