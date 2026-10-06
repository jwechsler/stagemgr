module RecurringProfile
  RECURRING_STATUSES = (
  ACTIVE, EXPIRED, PENDING, CANCELED, SUSPENDED =
    "Active", "Expired", "Pending", "Canceled", "Suspended"
)
  # Stripe subscription statuses that mean the member is paid up and current.
  LIVE_SUBSCRIPTION_STATUSES = %w[active trialing].freeze
  extend ActiveSupport::Concern

  included do
    belongs_to :address

    validates :address, presence: true
    validates :profile_id, uniqueness: { allow_nil: true, allow_blank: true, :unless => proc { |profile|
      profile.profile_id.eql?(PaymentProcessing::BogusResponse::PROFILE_ID)
    } }

    after_save :notify_on_suspension, :if => proc { |record|
      record.saved_change_to_attribute?(:status) && record.suspended?
    }
  end

  def active?
    status.eql?(ACTIVE)
  end

  def pending?
    status.eql?(PENDING)
  end

  def self.create_recurring_profile(order, start_date, recurring_amount, profile_description,
                                    max_failed_payments, additional_options = {})
    raise "This functionality has been deprecated"
    gateway ||= PaymentProcessing.recurring_gateway
    f_name, l_name = order.address.parse_full_name
    order.credit_card_expiration_year = Order.fix_expiration_year(order.credit_card_expiration_year.to_s)
    credit_card = PaymentProcessing.credit_card(order.credit_card_type,
                                                f_name,
                                                l_name,
                                                order.credit_card_number,
                                                order.credit_card_expiration_month,
                                                order.credit_card_expiration_year,
                                                order.credit_card_verification_number)
    options = { :ip => order.ip_address,
                :order_id => order.id,
                :email => order.address.email,
                :description => profile_description,
                :start_date => start_date,
                :period => 'Month', :frequency => 1, :max_failed_payments => max_failed_payments,
                :auto_bill_outstanding => true }
    options.merge!(additional_options) unless additional_options.nil?
    gateway.recurring((recurring_amount * 100).to_i, credit_card, options)
  end

  protected

  def get_profile_data
    if profile_id.starts_with?('sub_') then # stripe @todo remove at transition
      PaymentProcessing.gateway.subscription(profile_id)
    else
      response = gateway.status_recurring(profile_id)
      response.params
    end
  end

  public

  # Syncs from the Stripe subscription. With none to read (no profile yet, or
  # a PayPal-era profile) there is nothing to sync, so the recorded status is
  # kept; only a record with no status yet starts as Pending. Until 2026-10
  # this branch set Pending outright, so viewing a PayPal-era membership's
  # order in admin flipped a paying member to Pending.
  def update_from_profile(subscription_id = nil)
    self.profile_id = subscription_id if profile_id.blank? && subscription_id.present?
    return self.status ||= PENDING unless stripe_profile?

    subscription = get_profile_data
    self.start_date = Time.at(subscription.start_date).to_date unless subscription.start_date.nil?
    sync_ended_at(subscription)
    self.recurring_amount = subscription.items.data.first['price'].unit_amount.to_f / 100.0
    self.next_billing_date = Time.at(subscription.current_period_end).to_date unless subscription.current_period_end.nil?
    self.cancel_at_period_end = cancel_pending?(subscription)
    self.status = status_for_subscription(subscription.status)
  end

  # A scheduled end shows as "Cancel pending" whichever way it was set: the
  # member canceling at period end, or a gift subscription created with
  # cancel_at (StripeGateway#gift_cancel_at), for which Stripe reports
  # cancel_at_period_end false. Folded into the one column rather than adding
  # another; next_billing_date already shows the final period's end.
  def cancel_pending?(subscription)
    subscription.cancel_at_period_end || subscription.cancel_at.present?
  end

  def stripe_profile?
    profile_id.present? && profile_id.starts_with?('sub')
  end

  def status_for_subscription(subscription_status)
    if LIVE_SUBSCRIPTION_STATUSES.include?(subscription_status)
      ACTIVE
    elsif ['canceled', 'unpaid'].include?(subscription_status)
      CANCELED
    else
      SUSPENDED
    end
  end

  # Stripe's ended_at is authoritative when set. A live subscription (active
  # or trialing) has not ended, so any ended_at left from an earlier ending is
  # stale and is cleared; reports close a membership's window at ended_at, so
  # a stale date drops a paying member. Other statuses keep a date stamped by
  # staff (Membership#stamp_ended_at_on_close).
  def sync_ended_at(subscription)
    if subscription.ended_at
      self.ended_at = Time.at(subscription.ended_at).to_date
    elsif LIVE_SUBSCRIPTION_STATUSES.include?(subscription.status)
      self.ended_at = nil
    end
  end

  def update_from_profile!
    update_from_profile
    save!
    self
  end

  def current_status
    case
    when pending?
      PENDING
    when active?
      ACTIVE
    else
      status
    end
  end

  def active?(as_of = nil)
    status == ACTIVE
  end

  def suspended?
    status == SUSPENDED
  end

  def pending?
    status == PENDING
  end

  # No longer entitled to member benefits. Expired (a one-time membership
  # past its term, ExpireOneTimeMembershipsJob) counts: until 2026-10 it did
  # not, so the MyEmma sync re-added an expired member instead of removing them.
  def inactive?
    [Membership::CANCELED, Membership::SUSPENDED, Membership::EXPIRED].include?(status)
  end

  def canceled?
    status == Membership::CANCELED
  end

  def recurring_order
    raise "RecurringProfile#recurring_order not yet implemented"
  end

  def reactivate
    gateway ||= PaymentProcessing.recurring_gateway
    gateway.reactivate_recurring(profile_id)
  end

  def cancel
    gateway ||= PaymentProcessing.recurring_gateway
    gateway.cancel_recurring(profile_id)
  end

  def notify_on_suspension
    return if recurring_order.nil?

    recurring_order.notify_suspended
    recurring_order.save
  end
end
