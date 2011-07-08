class MembershipLineItem < LineItem
  validates_presence_of :membership_offer
  belongs_to :membership_offer
  belongs_to :membership
  after_create :create_membership
  before_destroy :delete_membership
  attr_accessor :address

  private
  def create_membership
    self.membership = Membership.create
    self.membership.member_since=Date.today
    self.membership.membership_offer=self.membership_offer
    self.membership.status=Membership::ACTIVE
    self.membership.address_id=self.order.address.id
  end

  def delete_membership
    membership.destroy if !membership.nil?
  end

end