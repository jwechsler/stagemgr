class DonationLineItem < LineItem
  validates_presence_of :donation_amount
end
