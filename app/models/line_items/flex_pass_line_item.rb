class FlexPassLineItem < LineItem
  validates_presence_of :flex_pass_offer, :ticket_count
  belongs_to :flex_pass_offer
  belongs_to :flex_pass
  
  def price
    self.flex_pass_offer.price
  end

  def total
    price
  end
  
  def after_create
    self.flex_pass = FlexPass.create!(:flex_pass_offer=>self.flex_pass_offer,:order=>self.order,:address=>self.order.address)
    self.save!
  end
  
end