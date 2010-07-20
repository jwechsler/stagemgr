class SpecialOfferLineItem < LineItem
  validates_presence_of :special_offer

  def price
    self.special_offer.calculate_discount(self.order)
  end

  def total
    price
  end
end