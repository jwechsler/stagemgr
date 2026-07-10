class MembershipOrder < Order
  include RecurringOrder

  has_one :membership_line_item, foreign_key: :order_id, dependent: :destroy, inverse_of: :membership_order
  delegate :membership, to: :membership_line_item
  validates_associated :membership_line_item
  accepts_nested_attributes_for :membership_line_item, :recurring_payments, allow_destroy: true

  after_initialize :ensure_membership_line_item_exists

  # after_commit :update_membership_profile, :if=>:has_membership?

  def transition_processing_to_processed!(redirect_to = nil)
    raise "#{membership_offer.name} passes are issued by the box office and cannot be purchased." if membership_offer.timed?

    build_membership_line_item(membership_offer: membership_offer) if membership_line_item.nil?
    nil
    begin
      subscription_id = PaymentProcessing.create_subscription(self)

      membership_line_item.membership.profile_id = subscription_id
      membership_line_item.membership.update_from_profile

      membership_line_item.membership.preferred_seating = special_request
      membership_line_item.membership.save!
      super
    rescue StandardError => e
      raise "There was a problem setting up your account for the #{membership_offer.name} payment plan. #{e.message}"
    end
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
      [Date.today, membership.ended_at.nil? ? Date.today : membership.ended_at].min

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

  def create_proper_payment_in_amount_of!(_amount, _payment_options = {})
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
      end_date = [Date.today, membership.ended_at.nil? ? Date.today : membership.ended_at].min
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
      end_date = [Date.today, membership.ended_at.nil? ? Date.today : membership.ended_at].min
      ((end_date.year * 12) + end_date.month) - ((member_start_date.year * 12) + member_start_date.month)
    end
  end

  private # ... might be ghost methods

  def time_to_hold_in_transition
    8.hours
  end
end
