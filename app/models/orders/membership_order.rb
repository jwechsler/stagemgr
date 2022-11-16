class MembershipOrder < Order
  include RecurringOrder

  has_one :membership_line_item, :foreign_key=>:order_id, :dependent => :destroy, inverse_of: :membership_order

  validates_associated :membership_line_item
  accepts_nested_attributes_for :membership_line_item, :recurring_payments, :allow_destroy=>true

  after_initialize :ensure_membership_line_item_exists

  # after_commit :update_membership_profile, :if=>:has_membership?

  def transition_processing_to_processed!(redirect_to = nil)
    self.build_membership_line_item(membership_offer:membership_offer) if membership_line_item.nil?
    subcription_id = nil
    begin
      subscription_id = PaymentProcessing.create_subscription(self)

      membership_line_item.membership.profile_id = subscription_id
      membership_line_item.membership.update_from_profile

      membership_line_item.membership.preferred_seating = self.special_request
      membership_line_item.membership.save!
      super
    rescue StandardError => e
      raise RuntimeError, "There was a problem setting up your account for the #{membership_offer.name} payment plan. #{e.message}"
    end
  end

  def display_code()
    "MEMBERSHIP"
  end

  def number_of_tickets
    BigDecimal("0", 2)
  end

  def recurring_profile
    self.membership
  end

  def recurring_offer
    self.membership_offer
  end

  def description
    "Member for #{self.months_active}"
  end

  def to_s
    self.membership.nil? ? "Unknown" : "#{self.membership.current_status} #{self.months_active}"
  end

  def membership
    self.membership_line_item.membership
  end

  def membership_offer
    self.membership_line_item.membership_offer
  end

  def has_membership?
    !self.membership.nil?
  end

  def update_membership_profile
    Resque.enqueue(UpdateMembershipProfile, self.membership.id) if self.changed?
  end

  def valid_payment_types_for(current_user)
    valid_payment_types = super
    valid_payment_types.select {|pt| pt.is_a? CreditCardPaymentType }
  end

  def link_to_address_of_record
    super
    unless self.membership_line_item.membership.nil?
      self.membership_line_item.membership.address = self.address
      self.membership_line_item.membership.save!
    end
    self
  end

  def set_defaults
    super
    unless self.membership_line_item.nil?
      self.membership_line_item.order=self
      self.membership_line_item.membership.address = self.address if !self.membership_line_item.membership.nil?
    end
  end

  def is_balanced_transaction?
    true
  end

  # membership orders only have a value based on payments
  def total
    self.total_paid
  end

  def create_proper_payment_in_amount_of!(amount, payment_options = {})
    self.membership.update_from_profile!
    if self.membership.active?
      create_recurring_payment
    end
  end

  def unique_line_items(reload_line_items=false)
    result = super
    result << self.membership_line_item unless self.membership_line_item.nil?
    result
  end

  def all_line_items(reload_line_items = false)
    result = super(reload_line_items)
    result << self.membership_line_item unless self.membership_line_item.nil?
    result
  end


  def time_to_hold_in_transition
    8.hours
  end

  def transition_processing_to_processing!(redirect_to = nil)
    self.transition_new_to_processing!(redirect_to)
  end

  protected
  def ensure_membership_line_item_exists
    self.build_membership_line_item if self.membership_line_item.nil?
  end


  def cascade_address_to_nested_items
    super
    membership_line_item.address = self.address unless membership_line_item.nil?
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
    if self.do_not_create_tasks.nil? && self.saved_change_to_status? && self.status == PROCESSED
          self.tasks << OutreachTask.new(:execute_at=>self.starting_at + 4.months,
                                         :method_symbol=>:membership_friend_pass,
                                         :repeat_monthly_interval => 6) unless self.membership_offer.use_member_friend_code.blank?
    end
    super
  end


  def self.register_payment_to_profile(profile_id, amount)
    order = nil
    membership = Membership.find_by(profile_id: profile_id)
    unless membership.nil?
      order = membership.membership_order.create_recurring_payment!('Subscription Payment', amount: amount)
    end
    order
  end

  protected
  def months_active
    if self.membership.nil?
      "ERROR. Membership data missing"
    else
      member_start_date = membership.start_date || membership.created_at.to_date
      end_date = [Date.today, self.membership.ended_at.nil? ? Date.today : self.membership.ended_at].min
      months = (end_date.year * 12 + end_date.month) - (member_start_date.year * 12 + member_start_date.month)
      if months == 0
        days = (end_date - member_start_date).to_i
        "#{days} day#{'s' if days != 1}"
      else
        "#{months} month#{'s' if months != 1}"
      end
    end
  end
end
