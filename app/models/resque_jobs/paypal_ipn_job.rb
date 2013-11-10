class PaypalIpnJob

  @queue = :sync

  def self.profile_id(params)
    params['recurring_payment_id']
  end

  def self.referenced_profile(params)
    profile_id = params['recurring_payment_id']
    profile = Membership.find_by_profile_id(profile_id)
    profile = Pledge.find_by_profile_id(profile_id) if profile.nil?
    raise "Cannot locate profile with payment ID '#{profile_id}'" if profile.nil?

    profile
  end

end
