class PurgeExpiredSpecialOffers
  @queue = :maintenance

  def self.perform()
    SpecialOffer.purge_expired_offers
  end
end
