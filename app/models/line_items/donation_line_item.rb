class DonationLineItem < LineItem
  validates_presence_of :donation_amount

  def total
    donation_amount
  end
end
