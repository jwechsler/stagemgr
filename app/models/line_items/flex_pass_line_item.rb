class FlexPassLineItem < LineItem
  validates_presence_of :ticket_count
  belongs_to :flex_pass_offer
  has_many :flex_passes, dependent: :destroy

  after_create :create_flex_passes

  def price
    self.flex_pass_offer.price
  end

  def total
    price * ticket_count
  end

  def create_flex_passes
    self.ticket_count.times do
      self.flex_passes.create!(:flex_pass_offer=>self.flex_pass_offer,:order=>self.order,:address=>self.order.address)
    end
  end

  def flex_pass
    self.flex_passes.first
  end

  def to_s
    "#{self.ticket_count} #{self.flex_pass_offer.name}"
  end

end
