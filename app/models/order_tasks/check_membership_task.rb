class CheckMembershipTask < OrderTask
  protected

  def execute!
    membership = self.order.membership
    if membership.blank? || attempts > 12
      return false
    end

    membership.update_from_profile!
    result = false
    if Date.today > membership.next_billing_date then

      if membership.is_active?
        new_payment = self.order.create_recurring_payment

        if new_payment.nil?
          result = false
        else
          self.order.tasks << CheckMembershipTask.new(:execute_at=>membership.next_billing_date + 1.day)
          self.order.payments << new_payment
          new_payment.note = "Automatic payment created by membership check task"
          self.order.save!
          result = true
        end
      end
    else
      self.execute_at = membership.next_billing_date
      result=false
    end

    result
  end
end