class MembershipLineItem < LineItem
  validates_presence_of :membership_offer
  validates_presence_of :membership
  belongs_to :membership_offer
  belongs_to :membership
  before_validation :create_membership
  after_save :save_membership
  before_destroy :delete_membership
  attr_accessor :address

  private
  def create_membership
    if self.membership.nil?

      self.membership = Membership.new
      self.membership.member_since=Date.today
      self.membership.membership_offer=self.membership_offer
      self.membership.status=Membership::ACTIVE
      self.membership.address_id=self.address
    end
  end

  def save_membership
    membership.save!
  end

  def delete_membership
    membership.destroy if !membership.nil?
  end

end