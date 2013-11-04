class ProcessSuspendRecurringPaypalPayment < PaypalIpnJob

  def self.perform(params)

    membership = referenced_membership(params)

    membership.status = Membership::SUSPENDED
    membership.save!
  end

end
