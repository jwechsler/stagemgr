class MembershipOrder < Order
  include RecurringOrder

  has_one :membership_line_item, :foreign_key=>:order_id, :dependent => :destroy

  validates_associated :membership_line_item
  accepts_nested_attributes_for :membership_line_item, :recurring_payments, :allow_destroy=>true

  after_initialize :ensure_membership_line_item_exists

  # after_commit :update_membership_profile, :if=>:has_membership?

  def transition_processing_to_processed!(redirect_to = nil)
    Rails.logger.debug("PROCESSING TO PROCESSED")
    self.build_membership_line_item(membership_offer:membership_offer) if membership_line_item.nil?
    trial_amount = membership_offer.trial_amount.nil? ? 0 : (membership_offer.trial_amount*100).to_i
    success = false
    additional_options = { :trial_amount    => trial_amount,
                           :trial_frequency => 1,
                           :trial_period    => 'Month',
                           :trial_cycles    => membership_offer.trial_period
                         }
    response = RecurringProfile.create_recurring_profile(self,
                                        (self.gift? && !self.gift_date.blank?) ?  self.gift_date : Date.today,
                                        membership_offer.recurring_cost,
                                        membership_offer.billing_agreement, 1,
                                        additional_options)
    if response.success?
      Rails.logger.debug("*** RECURRING PROFILE #{response.to_yaml}")
      profile_id = response.params["profile_id"]
      membership_line_item.membership.profile_id = profile_id
      membership_line_item.membership.status = response.params["profile_status"][0..-8]
      membership_line_item.membership.preferred_seating = self.special_request
      membership_line_item.membership.save!
      super
    else
      raise RuntimeError, "There was a problem setting up your account for the #{membership_offer.name} payment plan. #{response.message}"
    end
  end

  def display_code()
    "MEMBERSHIP"
  end

  def ticketing_fee
    BigDecimal.new("0", 2)
  end

  def number_of_tickets
    BigDecimal.new("0", 2)
  end

  def recurring_profile
    self.membership
  end

  def recurring_offer
    self.membership_offer
  end

  def description
    "Membership " + (self.months_active.blank? ? "" : "[#{self.months_active}]")
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

  def transition_processing_to_processing!(redirect_to = nil)
    self.transition_new_to_processing!(redirect_to)
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
    if self.membership.nil?
      "ERROR. Membership data missing"
    else
      if (self.membership.number_cycles_completed || 0) == 0
        ""
      else
        "#{self.membership.number_cycles_completed} month#{'s' if self.membership.number_cycles_completed > 1}"
      end
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
    # Resque.enqueue_in(delay, SyncAddressToSalesforce, self.address_id)
    super
  end

  def self.syncable_statuses
    return self.attended_statuses + super
  end

end

