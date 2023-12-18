class MembershipPayment < PassPayment
  belongs_to :membership, inverse_of: :membership_payments

  def member_code
    self.membership.member_code
  end

  def customer_visible_amount
    0.0
  end

  def payment_info
    membership.member_code
  end

  def member_code=(code)
    self.membership = Membership.find_by_member_code(code)
    raise UnknownMembershipCode if self.membership.nil?
  end

  def receipt_description
    "Membership ##{membership.member_code}"
  end

  def process!(order = nil)
    if !order.address.email.blank? && self.membership.address.email.downcase.strip != order.address.email.downcase.strip
      raise 'Member ID does not match provided email address'
    end
    raise 'That member ID is not active. Please call the box office for assistance.' unless membership.active?
    self.membership.verify_applicable_for(self.order || order)
    super
  end

end