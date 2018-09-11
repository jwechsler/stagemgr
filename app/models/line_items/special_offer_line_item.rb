class SpecialOfferLineItem < LineItem
  validates_presence_of :special_offer
  belongs_to            :special_offer

  def price
    self.special_offer.calculate_discount(self.order)
  end

  def total
    price
  end

  def ticket_count
    0
  end

  def mark_redeemed
    special_offer.redeem_one_use!
  end

  def receipt_total
    self.price
  end

  def description
    self.special_offer.description(self.order)
  end

  def receipt_description
    self.special_offer.code
  end

end