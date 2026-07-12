# Marks Active special offers Inactive when the performance, production,
# expiration date, or performance date range they target ended more than a
# month ago. Enqueued on demand from the admin Special Offers page and weekly
# via schedule.yml. See SpecialOffer.deactivate_stale_offers for the criteria.
class DeactivateStaleSpecialOffers
  @queue = :maintenance

  def self.perform
    count = SpecialOffer.deactivate_stale_offers
    Rails.logger.info "DeactivateStaleSpecialOffers: deactivated #{count} stale special offers"
  end
end
