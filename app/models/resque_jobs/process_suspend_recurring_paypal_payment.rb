class ProcessSuspendRecurringPaypalPayment < PaypalIpnJob
  @queue = :maintenance

  def self.perform(params)
    profile = referenced_profile(params)

    profile.status = Membership::SUSPENDED
    profile.save!
  end
end
