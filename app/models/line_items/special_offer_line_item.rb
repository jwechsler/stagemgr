class SpecialOfferLineItem < LineItem
  belongs_to            :special_offer, inverse_of: :special_offer_line_items
  belongs_to            :order, inverse_of: :special_offer_line_item
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
