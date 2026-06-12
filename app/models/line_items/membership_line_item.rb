class MembershipLineItem < LineItem
  validates :membership_offer, presence: true
  validates :membership, presence: true
  validates :address, presence: true
  belongs_to :membership_offer
  belongs_to :membership
  belongs_to :address
  belongs_to :membership_order, foreign_key: :order_id, optional: true, inverse_of: :membership_line_item

  accepts_nested_attributes_for :membership

  after_initialize :create_membership
  before_save :save_membership
  before_destroy :delete_membership

  private

  def create_membership
    return unless membership.nil?

    self.membership = Membership.new
    membership.member_since = Date.today
    membership.membership_offer = membership_offer
    membership.status = Membership::PENDING
    membership.address = address
  end

  def save_membership
    membership.save! unless membership.nil?
  end

  def delete_membership
    membership.destroy unless membership.nil?
  end
end
