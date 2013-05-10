class MembershipOrder < Order

  belongs_to :membership_offer
  has_many :membership_line_items, :foreign_key=>:order_id, :dependent => :destroy
  has_many :recurring_payments, :foreign_key=>:order_id
  validates_associated :membership_line_items
  accepts_nested_attributes_for :membership_offer, :membership_line_items, :recurring_payments, :allow_destroy=>true

  def display_code()
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

  def description
    "Membership " + (self.months_active.blank? ? "" : "[#{self.months_active}]")
  end

  def to_s
    "#{self.membership.current_status} #{self.months_active}"
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
    CreditCardPaymentType.all
  end

  def link_to_address_of_record
    super
    self.membership_line_items.each do |li|
      unless li.membership.nil?
        li.membership.address = self.address
        li.membership.save!
      end
    end
    self
  end

  def set_defaults
    super
    self.membership_line_items.each { |di| di.order=self
    di.membership.address = self.address if !di.membership.nil? }
  end

  def total(reload_line_items=false)
    self.value_of_all_payments
  end

  def create_recurring_payment(note = nil, additional_info = {})
    payment = RecurringPayment.new
    payment.amount = additional_info[:amount] || self.membership.membership_offer.recurring_cost
    payment.note = note || "Automatically created"
    payment.transaction_id = additional_info[:transaction_id] || self.membership.profile_id
    payment.ipn_track_id = additional_info[:ipn_track_id]
    payment.processed_on = additional_info[:processed_on]
    payment.payment_fee = additional_info[:payment_fee]
    self.payments << payment
    payment
  end

  def create_proper_payment_in_amount_of!(amount, payment_options = {})
    self.membership.update_from_profile!
    if self.membership.active? && self.membership.number_cycles_completed > 0
      create_recurring_payment
    end
  end

  def unique_line_items(reload_line_items=false)
    (super + self.membership_line_items(reload_line_items)).uniq
  end

  def all_line_items(reload_line_items = false)
    super(reload_line_items) + self.membership_line_items
  end

  protected


  def cascade_address_to_nested_items
    super
    membership_line_items.each { |li| li.address = self.address }
  end


  def transition_new_to_processing!(redirect_to = nil)
    super

  end

  def starting_at
    [Time.now, self.gift_date.nil? ? Time.now : self.gift_date.to_datetime].max
  end

  def create_receipt_task

    self.tasks << OutreachTask.new(:execute_at=>self.starting_at + 23.hours, :method_symbol=>:membership_confirmation)

  end

  def create_transfer_ownership_task
    self.tasks << TransferOwnershipTask.new(:execute_at=>self.starting_at)
  end


  def create_mail_list_task
    self.tasks << MyEmmaTask.new(:execute_at=>Time.now + 5.minutes, :additional_groups=>[self.membership_offer.myemma_group]) if !self.address.email.nil?
  end

  def set_tasks_after_save
    if self.do_not_create_tasks.nil? && self.status_changed? && self.status == PROCESSED
          self.tasks << OutreachTask.new(:execute_at=>self.starting_at + 4.months,
                                         :method_symbol=>:membership_friend_pass,
                                         :repeat_monthly_interval => 6) unless self.membership_offer.use_member_friend_code.blank?
    end
    super
  end

  protected
  def months_active
    if (self.membership.number_cycles_completed || 0) == 0
      ""
    else
    "#{self.membership.number_cycles_completed} month#{'s' if self.membership.number_cycles_completed > 1}"
    end

  end
end