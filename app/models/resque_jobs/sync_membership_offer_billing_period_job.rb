class SyncMembershipOfferBillingPeriodJob
  @queue = :sync

  # Reads the billing period of the offer's Stripe Price and caches it on the
  # offer (MembershipOffer#billing_period_for). update_columns, so saving the
  # period does not re-enqueue this job. A price Stripe does not know (live
  # price ids against a test-mode key, or a deleted price) leaves the offer
  # unsynced, which the analysis treats as monthly. Any other error raises,
  # so the job lands in Resque's failed queue for a retry.
  def self.perform(membership_offer_id)
    offer = MembershipOffer.find_by(id: membership_offer_id)
    return if offer.nil? || offer.price_id.blank?

    period = PaymentProcessing.price_billing_period(offer.price_id)
    offer.update_columns(billing_interval: period[:interval], billing_interval_count: period[:interval_count],
                         billing_period_synced_at: Time.current)
  rescue Stripe::InvalidRequestError => e
    Rails.logger.warn("[SyncMembershipOfferBillingPeriodJob] offer #{membership_offer_id}: " \
                      "Stripe price #{offer&.price_id} not found, left unsynced (#{e.message})")
  end
end
