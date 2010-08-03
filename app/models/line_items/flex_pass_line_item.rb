class FlexPassLineItem < LineItem
  validates_presence_of :flex_pass_offer
  validates_presence_of :flex_pass
  belongs_to :flex_pass_offer
  belongs_to :flex_pass
  
  def price
    self.flex_pass_offer.price
  end

  def total
    price
  end
  
end