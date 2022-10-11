class DonationOrder < Order

  has_many :donation_line_items, :foreign_key=>:order_id, inverse_of: :donation_order

  accepts_nested_attributes_for :donation_line_items,
                                :allow_destroy => true

  validates_associated :donation_line_items

  # after_save :update_address_aggregates

  def refundable?
    [Order::PROCESSED, Order::FULFILLED].include?(self.status)
  end

  def display_code()
    "DONATION"
  end

  def to_s
    "Donation (#{self.campaign})"
  end

  def total
    self.donation_line_items.sum(:amount)
  end

  def description
    self.to_s
  end

  def all_line_items(reload_line_items = false)
    self.donation_line_items.reload if reload_line_items
    super(reload_line_items) +
        self.donation_line_items
  end

  def valid_payment_types_for(current_user)
    valid_payment_types = super
    valid_payment_types.select {|pt| pt.is_a? CurrencyPaymentType }
  end

  def reload_associated
    super
    self.donation_line_items(true)
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

  def update_address_aggregates
    self.address.update_donor_levels!
  end

end
