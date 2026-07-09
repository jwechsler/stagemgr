class MembershipPayment < PassPayment
  belongs_to :membership, inverse_of: :membership_payments

  def receipt_description
    'Membership'
  end

  delegate :member_code, to: :membership

  def customer_visible_amount
    0.0
  end

  def payment_info
    membership.member_code
  end

  def member_code=(code)
    self.membership = Membership.find_by_member_code(code)
    raise UnknownMembershipCode if membership.nil?
  end

  def receipt_description
    "Membership ##{membership.member_code}"
  end

  def process!(order = nil)
    o = self.order || order
    unless membership.membership_offer.timed?
      if o.address.email.present? && membership.address.email.downcase.strip != o.address.email.downcase.strip
        raise 'Member ID does not match provided email address'
      end
    end
    raise 'That member ID is not active. Please call the box office for assistance.' unless membership.active?

    membership.verify_bookable_this_week!(o)
    membership.verify_applicable_for(o)
    super
  end

  def new_exchange_offset_payment
    offset_payment = super
    offset_payment.membership = membership
    offset_payment
  end
end
