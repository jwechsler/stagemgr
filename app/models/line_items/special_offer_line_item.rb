class SpecialOfferLineItem < LineItem
  belongs_to            :special_offer, inverse_of: :special_offer_line_items
  belongs_to            :order, inverse_of: :special_offer_line_item
  def price
    special_offer.calculate_discount(order)
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
    price
  end

  def description
    special_offer.description(order)
  end

  def receipt_description
    special_offer.code
  end
end
