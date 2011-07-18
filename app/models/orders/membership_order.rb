class MembershipOrder < Order

  belongs_to :membership_offer
  has_many :membership_line_items, :foreign_key=>:order_id
  has_many :recurring_payments, :foreign_key=>:order_id
  validates_associated :membership_line_items
  accepts_nested_attributes_for :membership_offer, :membership_line_items, :recurring_payments, :allow_destroy=>true

  def performance_code()
    "MEMBERSHIP"
  end

  def ticketing_fee
    BigDecimal.new("0", 2)
  end

  def ticket_quantity
    BigDecimal.new("0", 2)
  end

  def membership_offer
    self.membership_line_items.first.membership_offer if !self.membership_line_items.empty?
  end

  def set_membership_offer(offer)
    li = MembershipLineItem.create(:membership_offer=>offer, :address=>self.address)

    self.membership_line_items << li
  end

  def membership
    if (!self.membership_line_items.first.nil?)
      self.membership_line_items.first.membership
    else
      nil
    end
  end

  def valid_payment_types_for(current_user)
    valid_payment_types = Array.new
    valid_payment_types << Order::CREDIT_CARD
    valid_payment_types
  end

  def link_to_address_of_record
    super
    self.membership_line_items.each { |li| li.membership.address = self.address if !li.membership.nil? }
  end

  def set_defaults
    super
    self.membership_line_items.each { |di| di.order=self
    di.membership.address = self.address if !di.membership.nil? }
  end

  protected
  def cascade_address_to_nested_items
    super
    membership_line_items.each { |li| li.address = self.address }
  end

  def unique_line_items(reload_line_items=false)
    (super + self.membership_line_items(reload_line_items)).uniq
  end

  def transition_new_to_processing!(redirect_to = nil)
    super

  end

end