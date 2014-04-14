class MembershipOrder < Order
  include RecurringOrder
  belongs_to :membership_offer
  has_many :membership_line_items, :foreign_key=>:order_id, :dependent => :destroy
  validates_associated :membership_line_items
  accepts_nested_attributes_for :membership_offer, :membership_line_items, :recurring_payments, :allow_destroy=>true

  after_commit :update_membership_profile, :if=>:has_membership?


  def display_code()
    "MEMBERSHIP"
  end

  def ticketing_fee
    BigDecimal.new("0", 2)
  end

  def number_of_tickets
    BigDecimal.new("0", 2)
  end

  def membership_offer
    self.membership_line_items.first.membership_offer if !self.membership_line_items.empty?
  end

  def recurring_profile
    self.membership
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

  def has_membership?
    !self.membership.nil?
  end

  def update_membership_profile
    Resque.enqueue(UpdateMembershipProfile, self.membership.id)
  end

  def valid_payment_types_for(current_user)
    valid_payment_types = super
    valid_payment_types.select {|pt| pt.is_a? CreditCardPaymentType }
    valid_payment_types
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


  def is_balanced_transaction?
    true
  end


  def total(reload_line_items=false)
    self.value_of_all_payments
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


  def time_to_hold_in_transition
    8.hours
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


# Salesforce engine bits

class MembershipOrder

  def syncable?
    SalesforceSync.enabled?
  end

  def queue_sf_sync(delay = nil ) # membership orders just update the address record at present
    delay = 2.minutes if delay.nil?
    Resque.enqueue_in(delay, SyncAddressToSalesforce, self.address_id)
    super
  end

  def self.syncable_statuses
    return self.attended_statuses + super
  end

end

