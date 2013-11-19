class ProcessCancelRecurringPaypalPayment < PaypalIpnJob

  def self.perform(params)
    profile = referenced_profile(params)

    profile.status = Membership::CANCELED
    profile.save!
  end

end
