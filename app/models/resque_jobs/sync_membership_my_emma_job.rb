class SyncMembershipMyEmmaJob
  @queue = :sync

  # Keeps a membership's address in sync with its offer's MyEmma group.
  # Idempotent: decides add vs remove from the membership's state at RUN
  # time, so stale or duplicate enqueues are harmless. API errors raise
  # into the Resque failed queue deliberately (no swallowing).
  def self.perform(membership_id)
    return if MyEmma.disabled?

    membership = Membership.find_by(id: membership_id)
    return if membership.nil?

    group_id = membership.membership_offer&.myemma_group
    address = membership.address
    return if group_id.blank? || address.nil? || address.email.blank?

    if membership.inactive?
      remove_from_group(address, group_id)
    else
      add_to_group(address, group_id)
    end
  end

  def self.add_to_group(address, group_id)
    member = MyEmma::Member.find_by_email(address.email) || MyEmma::Member.new
    member.name_first = address.first_name
    member.name_last = address.last_name
    member.email = address.email
    member.address = address.line1
    member.city = address.city
    member.state = address.state
    member.postal_code = address.zipcode
    member.save([group_id])
  end

  def self.remove_from_group(address, group_id)
    # Never pull someone off the list while another of their memberships
    # is still current.
    return if address.is_current_member?

    member = MyEmma::Member.find_by_email(address.email)
    return if member.nil?

    MyEmma::Group.find(group_id).remove_members(member)
  end
end
