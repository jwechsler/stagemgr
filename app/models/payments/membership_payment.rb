class MembershipPayment < Payment
  validates_presence_of :membership
  belongs_to :membership


  def member_code
    self.membership.member_code
  end

  def customer_visible_amount
    0.0
  end

  def member_code=(code)
    self.membership = Membership.find_by_member_code(code)
    raise UnknownMembershipCode if self.membership.nil?
  end
end