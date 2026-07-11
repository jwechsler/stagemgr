class SyncMembershipOfferMyEmmaGroupJob
  @queue = :sync

  # Fans out one SyncMembershipMyEmmaJob per ACTIVE membership on the
  # offer. Each child reads the offer's CURRENT myemma_group, so this is
  # add-only into the new group; the old group and inactive memberships
  # are untouched. Per-address API failures land individually in the
  # Resque failed queue and are retryable one at a time.
  def self.perform(membership_offer_id)
    return if MyEmma.disabled?

    offer = MembershipOffer.find_by(id: membership_offer_id)
    return if offer.nil? || offer.myemma_group.blank?

    Membership.where(membership_offer_id: offer.id, status: Membership::ACTIVE)
              .find_each { |membership| Resque.enqueue(SyncMembershipMyEmmaJob, membership.id) }
  end
end
