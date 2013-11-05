class ProcessCancelRecurringPaypalPayment < PaypalIpnJob

  def self.perform(params)
    membership = referenced_membership(params)

    membership.status = Membership::CANCELED
    membership.save!
  end

end
