class UpdateMembershipProfile
  @queue = :sync

  def self.perform(membership_id)
    m = Membership.find(membership_id)
    m.update_from_profile! unless m.profile_id.nil?
  end

end
