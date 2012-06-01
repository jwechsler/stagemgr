class FlexPassOrder < Order

  has_many :flex_pass_line_items, :foreign_key=>:order_id
  accepts_nested_attributes_for :flex_pass_line_items
  validates_associated :flex_pass_line_items

  def flex_pass_offer
    FlexPassOffer.find(self.flex_pass_line_items[0].flex_pass_offer_id) unless self.flex_pass_line_items.size == 0
  end


  def display_code()
    "FLEXPASS"
  end

  def valid_payment_types_for(current_user)
    valid_payment_types = super
    valid_payment_types.delete FLEX_PASS
    valid_payment_types.delete MEMBERSHIP
    valid_payment_types
  end

  def description
    self.flex_pass_line_items[0].flex_pass_offer.name
  end

  def to_s
    self.description
  end

  protected
  def set_theater
    self.theater_id = self.flex_pass_line_items[0].flex_pass_offer.theater_id
  end


  def create_receipt_task
    super
    self.tasks << OutreachTask.new(:execute_at=>Time.now + 5.minutes, :method_symbol=>:flexpass_confirmation)
  end


  def set_defaults
    super
    self.flex_pass_line_items.each { |tli| tli.order=self }
  end


end