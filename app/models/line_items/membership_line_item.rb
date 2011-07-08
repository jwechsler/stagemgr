class MembershipLineItem < LineItem
  validates_presence_of :membership_offer
  belongs_to :membership_offer
  belongs_to :membership
  after_create :create_membership
  attr_accessor :address

  private
  def create_membership
    self.membership = Membership.create!(:member_since=>Date.today,:membership_offer=>self.membership_offer,:status=>Membership::ACTIVE, :address=>self.order.address)
  end

end