class MembershipLineItem < LineItem
  validates_presence_of :membership_offer
  validates_presence_of :membership
  validates_presence_of :address
  belongs_to :membership_offer
  belongs_to :membership
  belongs_to :address
  belongs_to :membership_order, :foreign_key => :order_id, optional: true, inverse_of: :membership_line_item

  accepts_nested_attributes_for :membership

  after_initialize :create_membership
  before_save :save_membership
  before_destroy :delete_membership

  private

  def create_membership
    if self.membership.nil?

      self.membership = Membership.new
      self.membership.member_since = Date.today
      self.membership.membership_offer = self.membership_offer
      self.membership.status = Membership::PENDING
      self.membership.address = self.address
    end
  end

  def save_membership
    membership.save! unless membership.nil?
  end

  def delete_membership
    membership.destroy unless membership.nil?
  end
end
