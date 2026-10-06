class MembershipOrder < Order
  include RecurringOrder

  has_one :membership_line_item, foreign_key: :order_id, dependent: :destroy, inverse_of: :membership_order
  delegate :membership, to: :membership_line_item
  validates_associated :membership_line_item
  accepts_nested_attributes_for :membership_line_item, :recurring_payments, allow_destroy: true

  after_initialize :ensure_membership_line_item_exists

  # after_commit :update_membership_profile, :if=>:has_membership?

  # The base transition runs every check first; the Stripe subscription is
  # this order's charge (#charge_proper_payment!), so it is created last.
  def transition_processing_to_processed!(redirect_to = nil)
    raise "#{membership_offer.name} passes are issued by the box office and cannot be purchased." if membership_offer.timed?

    build_membership_line_item(membership_offer: membership_offer) if membership_line_item.nil?
    begin
      super
    rescue StandardError => e
      raise "There was a problem setting up your account for the #{purchase_description}. #{e.message}"
    end
  end

  # Nothing to build before the charge: the first payment is recorded from
  # the subscription once it exists.
  def build_proper_payment_in_amount_of(_amount, _payment_options = {})
    nil
  end

  # A one-time Stripe Price is charged once and the membership given an
  # expiry date; a recurring one becomes a Stripe subscription. An offer saved
  # moments ago may not have its billing period cached yet (the sync job runs
  # in the background), so read it now rather than guess it is recurring.
  def charge_proper_payment!(_payment)
    membership_offer.sync_billing_period! unless membership_offer.billing_period_synced?
    return charge_one_time_membership! if membership_offer.one_time_payment?

    charge_subscription_membership!
  end

  def display_code
    'MEMBERSHIP'
  end

  def number_of_tickets
    BigDecimal('0')
  end

  def recurring_profile
    membership
  end

  def recurring_offer
    membership_offer
  end

  def description
    if membership.active?
      "Member for #{months_active}"
    else
      member_start_date = membership.start_date || membership.created_at.to_date
      [Date.current, membership.ended_at.nil? ? Date.current : membership.ended_at].min

      "#{member_start_date} -> #{member_start_date + months_active_i.months}"
    end
  end

  def to_s
    membership.nil? ? 'Unknown' : "#{membership.current_status} #{months_active}"
  end

  delegate :membership_offer, to: :membership_line_item

  def has_membership?
    !membership.nil?
  end

  def update_membership_profile
    Resque.enqueue(UpdateMembershipProfile, membership.id) if changed?
  end

  def valid_payment_types_for(current_user)
    valid_payment_types = super
    valid_payment_types.select { |pt| pt.is_a? CreditCardPaymentType }
  end

  def link_to_address_of_record
    super
    unless membership_line_item.membership.nil?
      membership_line_item.membership.address = address
      membership_line_item.membership.save!
    end
    self
  end

  def set_defaults
    super
    return if membership_line_item.nil?

    membership_line_item.order = self
    membership_line_item.membership.address = address unless membership_line_item.membership.nil?
  end

  def balanced_transaction?
    true
  end

  # membership orders only have a value based on payments
  def total
    total_paid
  end

  # SUBSCRIPTION path only: the first payment follows the synced subscription.
  # A one-time membership has no subscription to sync and records its payment
  # in #charge_one_time_membership!.
  def create_proper_payment_in_amount_of!(_amount, _payment_options = {})
    return if membership.one_time?

    membership.update_from_profile!
    return unless membership.active?

    create_recurring_payment
  end

  def unique_line_items(reload_line_items = false)
    result = super
    result << membership_line_item unless membership_line_item.nil?
    result
  end

  def all_line_items(reload_line_items = false)
    result = super
    result << membership_line_item unless membership_line_item.nil?
    result
  end

  def transition_processing_to_processing!(redirect_to = nil)
    transition_new_to_processing!(redirect_to)
  end

  protected

  # membership.save! follows the subscription, so check it can save first.
  def ready_to_charge?
    return false unless super
    return true if membership.valid?

    errors.add(:base, membership.errors.full_messages.to_sentence)
    false
  end

  def ensure_membership_line_item_exists
    build_membership_line_item if membership_line_item.nil?
  end

  def cascade_address_to_nested_items
    super
    membership_line_item.address = address unless membership_line_item.nil?
  end

  def transition_new_to_processing!(redirect_to = nil)
    super
  end

  def starting_at
    [Time.now, gift_date.nil? ? Time.now : gift_date.to_datetime].max
  end

  # The day a one-time membership's term begins: the purchase date, or the
  # gift date when that is later (the day starting_at falls on).
  def term_start
    [Date.current, gift_date&.to_date].compact.max
  end

  def create_receipt_task
    tasks << OutreachTask.new(execute_at: starting_at + 23.hours,
                              method_symbol: :membership_confirmation)
  end

  def create_transfer_ownership_task
    tasks << TransferOwnershipTask.new(execute_at: starting_at)
  end

  def create_mail_list_task
    return if address.email.blank?

    task = MyEmmaTask.new(execute_at: Time.now + 5.minutes, order: self,
                          additional_groups: [membership_offer.myemma_group])
    task.save!
  end

  def set_tasks_after_save
    if do_not_create_tasks.nil? && saved_change_to_status? && processed? && membership_offer.use_member_friend_code.present?
      task = OutreachTask.new(execute_at: starting_at + 4.months,
                              method_symbol: :membership_friend_pass,
                              repeat_monthly_interval: 6,
                              order: self)
      task.save!
    end
    super
  end

  def self.register_payment_to_profile(profile_id, amount, invoice_id = nil)
    order = nil
    membership = Membership.find_by(profile_id: profile_id)
    unless membership.nil?
      order = membership.membership_order.create_recurring_payment!('Subscription Payment', amount: amount,
                                                                                            invoice_id: invoice_id)
    end
    order
  end

  def months_active
    if membership.nil?
      'ERROR. Membership data missing'
    else
      member_start_date = membership.start_date || membership.created_at.to_date
      end_date = [Date.current, membership.ended_at.nil? ? Date.current : membership.ended_at].min
      months = ((end_date.year * 12) + end_date.month) - ((member_start_date.year * 12) + member_start_date.month)
      if months == 0
        days = (end_date - member_start_date).to_i
        "#{days} day#{'s' if days != 1}"
      else
        "#{months} month#{'s' if months != 1}"
      end
    end
  end

  def months_active_i
    if membership.nil?
      0
    else
      member_start_date = membership.start_date || membership.created_at.to_date
      end_date = [Date.current, membership.ended_at.nil? ? Date.current : membership.ended_at].min
      ((end_date.year * 12) + end_date.month) - ((member_start_date.year * 12) + member_start_date.month)
    end
  end

  private # ... might be ghost methods

  def purchase_description
    membership_offer.one_time_payment? ? membership_offer.name : "#{membership_offer.name} payment plan"
  end

  # SUBSCRIPTION path: Stripe bills the recurring price and ends the
  # membership through the customer.subscription.* webhooks.
  def charge_subscription_membership!
    membership.profile_id = PaymentProcessing.create_subscription(self)
    membership.update_from_profile
    membership.preferred_seating = special_request
    membership.save!
    create_proper_payment_in_amount_of!(total)
  end

  # ONE-TIME path: one charge for the whole term. Nothing in Stripe will end
  # this membership, so it carries its own expiry date, which
  # ExpireOneTimeMembershipsJob acts on. The payment is recorded here, as a
  # RecurringPayment keyed by the invoice id like a subscription's, so
  # refunds made in Stripe find it (StripeRefundRecorder#recurring_source).
  def charge_one_time_membership!
    invoice = PaymentProcessing.charge_one_time(self)
    membership.start_date = term_start
    membership.expires_on = membership.start_date >> membership_offer.one_time_term_months
    membership.status = Membership::ACTIVE
    membership.preferred_seating = special_request
    membership.save!
    create_recurring_payment('One-time payment', amount: invoice.amount_paid / 100.0, invoice_id: invoice.id)
  end

  def time_to_hold_in_transition
    8.hours
  end
end
