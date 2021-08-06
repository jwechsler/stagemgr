module RecurringProfile
  RECURRING_STATUSES = (
  ACTIVE, EXPIRED, PENDING, CANCELED, SUSPENDED =
      "Active", "Expired", "Pending", "Canceled", "Suspended"
  )
  extend ActiveSupport::Concern
  included do
    belongs_to :address

    validates_presence_of :address
    validates_uniqueness_of :profile_id, allow_nil: true, allow_blank:true, :unless=>Proc.new {|profile| profile.profile_id.eql?(PaymentProcessing::BogusResponse::PROFILE_ID)}

    before_save :notify_on_suspension, :if=>Proc.new { |record|
      record.status_changed? && record.suspended?
    }

  end

  def self.create_recurring_profile(order,start_date, recurring_amount, profile_description,
                               max_failed_payments, additional_options = Hash.new)
    raise "This functionality has been deprecated"
    gateway ||= PaymentProcessing.recurring_gateway
    f_name, m_name, l_name = order.address.parse_full_name
    order.credit_card_expiration_year = Order.fix_expiration_year(order.credit_card_expiration_year.to_s)
    credit_card = PaymentProcessing.credit_card(  order.credit_card_type,
                                                  f_name,
                                                  l_name,
                                                  order.credit_card_number,
                                                  order.credit_card_expiration_month,
                                                  order.credit_card_expiration_year,
                                                  order.credit_card_verification_number)
    options = { :ip=>order.ip_address,
                :order_id =>order.id,
                :email=>order.address.email,
                :description => profile_description,
                :start_date=>start_date,
                :period=>'Month', :frequency=>1, :max_failed_payments=>max_failed_payments,
                :auto_bill_outstanding=> true
              }
    options.merge!(additional_options) unless additional_options.nil?
    response = gateway.recurring((recurring_amount * 100).to_i, credit_card, options)
    response
  end

  protected
  def get_profile_data
    if self.profile_id.starts_with?('sub_') then # stripe @todo remove at transition
      subscription = PaymentProcessing.gateway.subscription(self.profile_id)
    else
      response = gateway.status_recurring(self.profile_id)
      response.params
    end
  end

  public
  def update_from_profile(subscription_id = nil)
    self.profile_id = subscription_id if (self.profile_id.blank? && !subscription_id.blank?)
    unless self.profile_id.blank?
      subscription = get_profile_data
      self.start_date = Time.at(subscription.start_date).to_date unless subscription.start_date.nil?
      self.ended_at = Time.at(subscription.ended_at).to_date unless subscription.ended_at.nil?
      self.recurring_amount = subscription.items.data.first['price'].unit_amount.to_f / 100.0
      self.next_billing_date = Time.at(subscription.current_period_end).to_date unless subscription.current_period_end.nil?
      self.cancel_at_period_end = subscription.cancel_at_period_end
      profile_status = subscription.status
    else
      profile_status = PENDING
    end
    self.status = case
      when ['active','trialing'].include?(profile_status)
        ACTIVE
      when [CANCELED, 'canceled', 'unpaid'].include?(profile_status)
        CANCELED
      when ()
      when (['Cancelled',CANCELED].include?(profile_status))
        CANCELED
      else
        SUSPENDED
    end
  end

  def update_from_profile!
    self.update_from_profile
    self.save!
    self
  end


  def current_status
    case
    when self.pending?
      PENDING
    when self.active?
      ACTIVE
    else
      self.status
    end
  end

  def active?(as_of = nil)
    self.status == ACTIVE
  end

  def suspended?
    self.status == SUSPENDED
  end

  def pending?
    self.status == PENDING
  end

  def inactive?
    [Membership::CANCELED, Membership::SUSPENDED].include?(self.status)
  end

  def canceled?
    self.status == Membership::CANCELED
  end

  def recurring_order
    raise "RecurringProfile\#recurring_order not yet implemented"
  end

  def notify_on_suspension
    raise "RecurringProfile\#notify_on_suspension not yet implemented"
  end

  def reactivate
    gateway ||= PaymentProcessing.recurring_gateway
    gateway.reactivate_recurring(self.profile_id)
  end

  def cancel
    gateway ||= PaymentProcessing.recurring_gateway
    gateway.cancel_recurring(self.profile_id)
  end

  def notify_on_suspension
    self.recurring_order.notify_suspended
    self.recurring_order.save
  end


end
