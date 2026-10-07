# Sales and redemption counts for one flex pass offer, shown on its admin
# page. Outstanding shares FlexPass.outstanding with
# FlexPassOfferPassesDatatable, so the tile and the table always agree.
class FlexPassOfferUsage
  attr_reader :offer

  def initialize(offer)
    @offer = offer
  end

  def passes_sold
    @passes_sold ||= offer.flex_passes.count
  end

  def outstanding_count
    @outstanding_count ||= offer.flex_passes.outstanding.count
  end

  def expired_count
    @expired_count ||= offer.flex_passes.expired.count
  end

  def tickets_issued
    passes_sold * offer.number_of_tickets.to_i
  end

  def tickets_redeemed
    @tickets_redeemed ||= FlexPassPayment.where(flex_pass_id: offer.flex_passes.select(:id))
                                         .sum(:number_of_tickets)
  end

  def passes?
    passes_sold.positive?
  end
end
