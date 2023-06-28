class FlexPassOrder < Order

  has_one :flex_pass_line_item, :foreign_key=>:order_id, dependent: :destroy, inverse_of: :flex_pass_order
  
  delegate :flex_pass, to: :flex_pass_line_item
  delegate :flex_pass_offer, to: :flex_pass_line_item

  accepts_nested_attributes_for :flex_pass_line_item
  
  validates_associated :flex_pass_line_item
  
  before_destroy :has_no_placed_orders?

  def associated_theater_id
    unless flex_pass_line_item.nil?
      flex_pass_offer.theater_id
    else
      super
    end
  end

  def display_code()
    "FLEXPASS"
  end

  def all_line_items(reload_line_items = false)
    super(reload_line_items) << self.flex_pass_line_item
  end

  def valid_payment_types_for(current_user)
    valid_payment_types = super
    valid_payment_types.select {|pt| pt.is_a? CurrencyPaymentType }
  end

  def description
    self.flex_pass_offer.name
  end

  def to_s
    self.description
  end

  def flex_pass_payments
    payments.select { |p| p.is_a? FlexPassPayment }
  end

  def self.send_flex_pass_reminder
    email = $EMAIL_ADDRESS['flex_pass_notifications']

    unless email.blank?
      flex_pass_orders = FlexPassOrder.find_all_by_status(Order::PROCESSED)
      OrderMailer.send(:flex_pass_pending_reminder, flex_pass_orders).deliver
    end
  end

  def cancel!
    if flex_pass.upcoming_ticket_orders.count > 0 then
      errors.add(:error, "Cannot cancel a flex_pass with upcoming ticket orders")
      false
    else
      flex_pass.active=false 
      flex_pass.save!
      self.status = CANCELED
      self.save!
      errors.add(:info, "Flex Pass #{flex_pass.code} inactive")
      true
    end
  end

  def refundable?
    self.flex_pass_line_item.flex_pass.uses_remaining == self.flex_pass_line_item.flex_pass.flex_pass_offer.number_of_tickets
  end

  def has_placed_orders?
    FlexPassPayment.where(flex_pass_id: self.flex_pass).count > 0
  end

  def has_no_placed_orders?
    !self.has_placed_orders?
  end

  protected
  def create_receipt_task
    super
    unless self.suppress_receipt
      self.tasks << OutreachTask.new(:execute_at=>Time.now + 5.minutes, :method_symbol=>:flexpass_confirmation)
    end
  end

end