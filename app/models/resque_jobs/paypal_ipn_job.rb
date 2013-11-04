class PaypalIpnJob

  @queue = :sync

  def self.profile_id(params)
    params['recurring_payment_id']
  end

  def self.order_from_profile_id(profile_id)
    profile_id = params['recurring_payment_id']
    order = nil
    memberships = Membership.where('profile_id = ?', profile_id)
    return memberships.first.membership_order if memberships.count > 0
    nil
  end

  def self.referenced_membership(params)
    profile_id = params['recurring_payment_id']
    begin
      membership = Membership.find_by_profile_id(profile_id)
    rescue ActiveRecord::RecordNotFound
      raise "Cannot locate membership with payment ID '#{profile_id}'"
    end
    membership
  end

end
