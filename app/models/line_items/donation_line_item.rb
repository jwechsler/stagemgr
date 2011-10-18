class DonationLineItem < LineItem
  belongs_to :donation_order, :foreign_key=>:order_id
  validates_presence_of :donation_amount

  attr_accessor :donation_level

  before_validation :set_donation_amount_from_level

  def total
    donation_amount
  end

  private
  def set_donation_amount_from_level
    if !self.donation_level.blank?
      self.donation_amount = self.donation_level
    end
  end

end
