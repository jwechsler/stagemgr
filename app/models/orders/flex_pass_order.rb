class FlexPassOrder < Order

  has_many :flex_pass_line_items, :foreign_key=>:order_id, dependent: :destroy
  accepts_nested_attributes_for :flex_pass_line_items
  validates_associated :flex_pass_line_items
  before_destroy :has_no_placed_orders?

  def flex_pass_offer
    FlexPassOffer.find(self.flex_pass_line_items[0].flex_pass_offer_id) unless self.flex_pass_line_items.size == 0
  end

  def associated_theater_id
    if flex_pass_line_items.size > 0
      flex_pass_line_items[0].flex_pass_offer.theater_id
    else
      super
    end
  end

  def display_code()
    "FLEXPASS"
  end

  def all_line_items(reload_line_items = false)
    super(reload_line_items) + self.flex_pass_line_items(reload_line_items)
  end

  def valid_payment_types_for(current_user)
    valid_payment_types = super
    valid_payment_types.select {|pt| pt.is_a? CurrencyPaymentType }
  end

  def description
    self.flex_pass_line_items[0].flex_pass_offer.name
  end

  def to_s
    self.description
  end

  def flex_passes
    self.flex_pass_line_items.map { |fli| fli.flex_passes }.flatten
  end

  def flex_pass
    self.flex_passes.first
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

  def reload_associated
    super
    self.flex_pass_line_items(true)
  end

  def refundable?
    used = false
    self.flex_pass_line_items.each {|li|
      used ||= li.flex_pass.uses_remaining == li.flex_pass.flex_pass_offer.number_of_tickets
    }
    used
  end

  def has_placed_orders?
    FlexPassPayment.where(flex_pass_id: self.flex_passes.map{|fp| fp.id}).count > 0
  end

  def has_no_placed_orders?
    !self.has_placed_orders?
  end

  protected
  def set_theater
    self.theater_id = self.flex_pass_line_items[0].flex_pass_offer.theater_id unless self.flex_pass_line_items.empty?
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