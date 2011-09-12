class MembershipLineItem < LineItem
  validates_presence_of :membership_offer
  validates_presence_of :membership
  validates_presence_of :address
  belongs_to :membership_offer
  belongs_to :membership
  belongs_to :address
  belongs_to :membership_order, :foreign_key=>:order_id
  before_validation :create_membership
  after_save :save_membership
  before_destroy :delete_membership


  private
  def create_membership
    if self.membership.nil?

      self.membership = Membership.new
      self.membership.member_since=Date.today
      self.membership.membership_offer=self.membership_offer
      self.membership.status=Membership::ACTIVE
      self.membership.address=self.address
    end
  end

  def save_membership
    membership.save!
  end

  def delete_membership
    membership.destroy unless membership.nil?
  end

end