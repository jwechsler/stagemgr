module RecurringProfile
  RECURRING_STATUSES = (
  ACTIVE, EXPIRED, PENDING, CANCELED, SUSPENDED =
      "Active", "Expired", "Pending", "Canceled", "Suspended"
  )
  extend ActiveSupport::Concern
  included do
    belongs_to :address

    validates_presence_of :address
    validates_uniqueness_of :profile_id
    after_save :cancel_reconciliation_checks, :if=>Proc.new { |record|
      record.status_changed? && record.canceled?
    }

    before_save :notify_on_suspension, :if=>Proc.new { |record|
      record.status_changed? && record.suspended?
    }

  end

  def cancel_reconciliation_checks
    self.recurring_order.stop_sanity_checks
  end

  def self.create_recurring_profile(order,start_date, recurring_amount, profile_description,
                               max_failed_payments, additional_options = Hash.new)
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

  def get_profile_data
    gateway ||= PaymentProcessing.recurring_gateway

    response = gateway.status_recurring(self.profile_id)
    response.params
  end

  def update_from_profile(response = nil)
    response = self.get_profile_data if response.nil?
    self.number_cycles_completed = response["number_cycles_completed"] unless response["number_cycles_completed"].blank?
    self.number_cycles_remaining = response["number_cycles_remaining"] unless response["number_cycles_remaining"].blank?
    self.total_billing_cycles = response["total_billing_cycles"] unless response["total_billing_cycles"].blank?
    self.recurring_amount = response["amount"] unless response["amount"].blank?
    self.next_billing_date = response["next_billing_date"].to_date  unless response["next_billing_date"].blank?
    self.aggregate_amount = response["aggregate_amount"]  unless response["aggregate_amount"].blank?
    self.failed_payment_count = response["failed_payment_count"] unless response["failed_payment_count"].blank?
    self.outstanding_balance = response["outstanding_balance"].to_f unless response["outstanding_balance"].blank?
    self.final_payment_due_date = response['final_payment_due_date'].to_date unless response['final_payment_due_date'].blank?
    cycles = self.number_cycles_completed
    cycles ||=0
    profile_status = response["profile_status"][0..-8]  unless response["profile_status"].blank?
    self.status = case
      when (profile_status == ACTIVE)
        ACTIVE
      when (profile_status == PENDING) || (profile_status == ACTIVE && cycles == 0)
        PENDING
      when (['Cancelled',CANCELED].include?(profile_status))
        CANCELED
      when (profile_status == SUSPENDED)
        profile_status
      else
        "Other"
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
