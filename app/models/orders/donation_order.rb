class DonationOrder < Order
  has_many :donation_line_items, :foreign_key=>:order_id

  accepts_nested_attributes_for :donation_line_items,
                                :allow_destroy => true

  validates_associated :donation_line_items

  def refundable?
    self.status == Order::PROCESSED || self.status == Order::FULFILLED
  end

  def display_code()
    "DONATION"
  end

  def to_s
    "Donation"
  end

  def description
    self.to_s
  end

  def all_line_items(reload_line_items = false)
    super(reload_line_items) +
        self.donation_line_items(reload_line_items)
  end

  def valid_payment_types_for(current_user)
    valid_payment_types = super
    valid_payment_types.delete FLEX_PASS
    valid_payment_types.delete MEMBERSHIP
    valid_payment_types
  end

  protected

  def set_defaults
    super
    self.donation_line_items.each { |di| di.order=self }
  end

  def create_receipt_task
    super
    self.tasks << OutreachTask.new(:execute_at=>Time.now + 5.minutes, :method_symbol=>:donation_thank_you)
  end

end