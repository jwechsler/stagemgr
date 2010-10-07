class FlexPassLineItem < LineItem
  validates_presence_of :flex_pass_offer, :ticket_count
  belongs_to :flex_pass_offer
  has_many :flex_passes
  
  def price
    self.flex_pass_offer.price
  end

  def total
    price * ticket_count
  end
  
  def after_create
    self.ticket_count.times do
      self.flex_passes.create!(:flex_pass_offer=>self.flex_pass_offer,:order=>self.order,:address=>self.order.address)
    end
  end
  
end