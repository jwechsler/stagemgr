class ProcessCancelRecurringPaypalPayment < PaypalIpnJob
  @queue = :maintenance

  def self.perform(membership_id)
    profile = referenced_profile_by_id(membership_id)

    profile.status = Membership::CANCELED
    profile.save!
  end
end
