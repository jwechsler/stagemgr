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
  
end