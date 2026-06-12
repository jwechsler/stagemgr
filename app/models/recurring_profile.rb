module RecurringProfile
  RECURRING_STATUSES = (
  ACTIVE, EXPIRED, PENDING, CANCELED, SUSPENDED =
    "Active", "Expired", "Pending", "Canceled", "Suspended"
)
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

  def update_from_profile(subscription_id = nil)
    self.profile_id = subscription_id if profile_id.blank? && subscription_id.present?
    if profile_id.blank? || !profile_id.starts_with?('sub')
      profile_status = PENDING
    else # second condition is to wean off of paypal.  Remove it eventually
      subscription = get_profile_data
      self.start_date = Time.at(subscription.start_date).to_date unless subscription.start_date.nil?
      self.ended_at = Time.at(subscription.ended_at).to_date unless subscription.ended_at.nil?
      self.recurring_amount = subscription.items.data.first['price'].unit_amount.to_f / 100.0
      self.next_billing_date = Time.at(subscription.current_period_end).to_date unless subscription.current_period_end.nil?
      self.cancel_at_period_end = subscription.cancel_at_period_end
      profile_status = subscription.status
    end
    self.status = case
                  when ['active', 'trialing'].include?(profile_status)
                    ACTIVE
                  when [CANCELED, 'canceled', 'unpaid'].include?(profile_status)
                    CANCELED
                  when profile_status.eql?(PENDING)
                    PENDING
                  else
                    SUSPENDED
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

  def inactive?
    [Membership::CANCELED, Membership::SUSPENDED].include?(status)
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
    recurring_order.notify_suspended
    recurring_order.save
  end
end
