class Order < ApplicationRecord

  include Admin::ReportsHelper
  include ActionView::Helpers::NumberHelper
  include EmailValidatable

    # Associations
  belongs_to :theater, required: false, inverse_of: :orders
  belongs_to :performance, required: false, inverse_of: :orders

  belongs_to :payment_type, required: false
  belongs_to :address, inverse_of: :orders
  validates :address, presence: true
  
  belongs_to :recipient_address, class_name: 'Address', foreign_key: :recipient_address_id, required: false, inverse_of: :orders_as_recipient

  has_many :payments, inverse_of: :order
  has_many :exchange_payments
  has_many :tasks, class_name: 'OrderTask', dependent: :destroy, inverse_of: :order
  has_many :seats, foreign_key: :order_uuid, primary_key: :uuid, class_name: 'SeatAssignment', inverse_of: :order
  has_one :special_offer_line_item, inverse_of: :order
  has_many :service_line_items, dependent: :destroy, inverse_of: :order

  accepts_nested_attributes_for :payments, :address
  accepts_nested_attributes_for :special_offer_line_item,
                                :service_line_items,
                                :allow_destroy => true

  # Attribute accessors
  attr_accessor :special_offer_code, :door_sale, :additional_donation, :additional_donation_for_other,
                :email_confirmation, :add_to_email_list, :do_not_create_tasks, :give_gift_on_month, :give_gift_on_day,
                :credit_card_number, :credit_card_type, :credit_card_expiration_year, :credit_card_expiration_month,
                :credit_card_verification_number, :credit_card_confirmation_code, :credit_card_swipe, :flex_pass_code,
                :member_code, :check_number

  # Constants
  ORDER_STATUSES = (
  HOLD, NEW, PROCESSING, PROCESSED, REFUNDED, EXCHANGED, EXCHANGING, RELEASING, FULFILLED, CANCELED, UNCLAIMED, SPLIT =
      "Hold", "New", "Processing", "Processed", "Refunded", "Exchanged", "Exchanging", "Releasing", "Fulfilled", "Canceled", "Unclaimed", "Split").freeze

  HELD_STATUSES = [Order::HOLD].freeze

  HOLDING_SEAT_STATUSES = [HOLD, NEW, PROCESSING, PROCESSED, EXCHANGING, RELEASING, FULFILLED].freeze

  TRANSITORY_STATUSES = [NEW, PROCESSING].freeze
  
  UNPROCESSED_STATUSES = (TRANSITORY_STATUSES + [HOLD]).freeze

  ATTENDING_STATUSES = [PROCESSED, FULFILLED].freeze

  SETTLED_STATUSES = [PROCESSED, FULFILLED, UNCLAIMED, REFUNDED, EXCHANGED].freeze

  FINALIZED_STATUSES = (ATTENDING_STATUSES + [UNCLAIMED]).freeze

  RETURNED_STATUSES = [UNCLAIMED, REFUNDED, EXCHANGED].freeze

  REFERRALS = [
      "Email", "Mail", "Cast/Staff/Production Team", "Review/Feature", "Radio", "Newspaper Ad", "Facebook", "Twitter", "Word of Mouth", "Attended previous production", "Other"
  ].freeze


  # Order statuses that are considered transitory
  audited

  # Callbacks
  after_initialize :set_uuid_on_create
  before_validation :cascade_address_to_nested_items, :associate_service_line_items, :set_defaults
  before_validation :create_recipient_address, if: :gift?
  after_validation :prevent_status_rollbacks
  before_save :link_to_address_of_record, if: [:status_changed?, :processed?]
  before_save :cancel_pending_tasks, if: :newly_canceled?
  before_save :balanced_transaction?, if: [:status_changed?, :processed?]
  before_destroy :check_for_settled_payments

  after_save :set_tasks_after_save

  
  # Validations
  validates_inclusion_of :status, :in => ORDER_STATUSES, :if=>:status_is_provided?
  validates_presence_of :address
  validates_associated :address, unless: :new?
  validates_associated :payments,
                       :special_offer_line_item
  validates :hold_under, not_email: true

  # Custom Validations
  validate :validate_membership_payments, if: [:processed?]

  # Custom validation method
  def validate_membership_payments
    membership_payments.each { |p| p.membership.verify_applicable_for(self)}
  end

  #scopes 
  scope :transitory, -> {
    where(status: Order::TRANSITORY_STATUSES)
  }

  scope :settled, -> {
    where(status: Order::SETTLED_STATUSES)
  }

  scope :attending, -> {
    where(status: Order::ATTENDING_STATUSES)
  }

  scope :finalized, -> {
    where(status: Order::FINALIZED_STATUSES)
  }

  # implementation

  # Only ticket orders have a production
  def production
    nil
  end

  # Payment and total utility methods

  # total recorded revenue collected by box office
  def total_collected
    sum_payments = self.payments.reported_as_sales_collected.sum(:amount)
    BigDecimal(sum_payments,2)
  end

  # total recorded revenue for the order
  def total_revenue
    Rails.logger.warn "Deprecated method 'total_revenue' called from #{caller.join("\n")}"
    self.total_paid
  end

  # returns the total amount, regardless of reporting status
  def total_paid
    sum_payments = payments.loaded? ? payments.to_a.sum(&:amount) : payments.sum(:amount)
    BigDecimal(sum_payments, 2)
  end

  # total amount due from existing line items (not necessarily paid)
  def total_due
    line_items_sum = all_line_items.to_a.sum(&:total)
    line_items_sum < 0 ? BigDecimal('0', 2) : BigDecimal(line_items_sum, 2)
  end

  def total_override_payments
    sum = self.payments.override_payments_only.sum(:amount)
    BigDecimal(sum,2)
  end

  #returns the total payments visible to the customer, negative payment offsets
  # are never visible
  def customer_visible_total
    total = self.payments.to_a.sum { |payment| payment.customer_visible_amount }
    (total.nil? || total < 0) ?  BigDecimal('0',2) : BigDecimal(total,2)
  end

  # returns the actual total of the order by either total payments made (if there are any payments),
  # or the line items as a fallback
  def total
    a = payments.empty? ? total_due : total_paid
    a < 0 ? BigDecimal('0', 2) : a
  end

  def processing_fee
    BigDecimal(self.payments.to_a.sum(&:processing_fee),2)
  end

  def membership_payments
    self.payments.select { |p| p.is_a? MembershipPayment }
  end

  def flex_pass_payments
    self.payments.select { |p| p.is_a?(FlexPassPayment) }
  end

  def exchangeable?
    false
  end

  def exchanging?
    self.status.eql?(Order::EXCHANGING)
  end

  def holdable?
    false
  end

  def holding_seats?
    false
  end

  def fulfillable?
    self.status.eql?(Order::PROCESSED) || self.status == Order::UNCLAIMED
  end

  def fulfilled?
    self.status.eql?(Order::FULFILLED)
  end

  def refunded?
    self.status.eql?(Order::REFUNDED)
  end

  def printable?
    false
  end

  def contains_exchangeable_tickets?
    false
  end

  def new?
    self.status.eql?(Order::NEW)
  end

  def refundable?
    self.exchangeable?
  end

  def addresses
    [self.address]
  end

  def display_code()
    '???'
  end

  def seat_assignments_complete?
    true
  end

  def number_of_tickets
    0
  end

  def ticketing_fee
    BigDecimal(self.service_line_items.to_a.sum{|li| li.facility_fee }.to_s,2)
  end

  def valid_payment_types_for(current_user)
    PaymentType.valid_payment_types_for(current_user)
  end

  def show_confirmation_for?(current_user)
    current_user && (current_user.is_administrator? || current_user.is_box_office_user?)
  end

  def processing?
    self.status.eql?(PROCESSING)
  end

  def editable?
    [HOLD, NEW, PROCESSING, nil].include? self.status
  end

  def finalized?
    FINALIZED_STATUSES.include? self.status
  end

  def paid?
    self.finalized?
  end

  def unsettled?
    !self.settled?
  end

  def settled?
    SETTLED_STATUSES.include? self.status
  end

  def processed?
    PROCESSED == self.status
  end

  def returned?
    RETURNED_STATUSES.include? self.status
  end

  def unclaimed?
    self.status == UNCLAIMED
  end

  def attended?
    self.ATTENDING_STATUSES.include? self.status
  end

  def paid_with_currency?
    self.payment_type.is_a? CurrencyPaymentType
  end

  def paid_with_external?
    self.payment_type.is_a? ExternalPaymentType
  end

  def paid_with_flexpass?
    self.payment_type.is_a?(FlexPassPaymentType) && !self.flex_pass_payments.empty?
  end

  def paid_with_membership?
    !self.membership_payments.empty?
  end

  def paid_with_pass?
    self.paid_with_flexpass? || self.paid_with_membership?
  end

  def paid_with_flexpass
    unless flex_pass_payments.empty?
      FlexPass.find(flex_pass_payments.first.flex_pass_id)
    else
      FlexPass.find_by_code(self.flex_pass_code)
    end
  end

  def using_credit_card?
    self.payment_type.is_a?(CreditCardPaymentType) && self.total > 0
  end

  def held?
    self.status == HOLD
  end

  
  def special_offer_code_used
    self.special_offer_line_item.nil? ? '' : self.special_offer_line_item.special_offer.code
  end

  def reload_associated
    self.payments(true)
    self.tasks(true)
    self.special_offer_line_item(true)
  end


  def regularize_credit_card_expiration
    self.credit_card_expiration_year = Order.fix_expiration_year(self.credit_card_expiration_year)
    unless self.credit_card_expiration_year.blank? || self.credit_card_expiration_year.length > 2
      self.credit_card_expiration_year = "20" + self.credit_card_expiration_year
    end
  end

  def refund!
    Order.transaction do
      payments.each do |payment|
        if ((payment.respond_to? :refund!) && payment.report_as_sales_collected?)
          payment.refund!(nil, self.notes)
        end
      end
      self.all_line_items.each { |li| self.refund_line_items (li.refund!) if li.respond_to? :refund!  }
      self.status = REFUNDED
      create_notify_refund_task if self.fulfilled?
      self.save!
    end
  end

  def unclaimed!
    self.status = UNCLAIMED
    save!
  end

  def cancel!

    if self.payments.select{|p| !p.can_cancel?}.size > 0
      errors.add(:error, "Cannot cancel orders with payments")
      false
    else
      self.allow_deletion!
      self.destroy
      true
    end
  end

  def allow_deletion!
    @allow_destroy = true
  end

  def allow_deletion?
    @allow_destroy || false
  end

  def create_proper_payment_in_amount_of!(amount, payment_options = {})
    new_payment = self.payment_type.build_payment(amount, self, payment_options)
    self.payments << new_payment
    new_payment
  end

  def set_email_confirmation
    #now = DateTime.now
    #if !self.performance.nil? && (self.performance.performance_date > Date.today || (self.performance.performance_date == Date.today && self.performance.performance_time > Time.now - (60*60)))
    self.email_confirmation = 1
    #end
  end

  def update_special_offer_line_item_from_code!
    unless self.special_offer_code.blank? || !self.paid_with_currency?
      special_offer = SpecialOffer.find_by_order(self)
      unless special_offer.nil?
        if self.special_offer_line_item.nil?
          self.build_special_offer_line_item(:special_offer=>special_offer)
        else
          self.special_offer_line_item.special_offer=special_offer
        end
      else
        raise RuntimeError, "Unknown or inapplicable special offer code \"#{self.special_offer_code}\""
      end
    end
  end

  def description
    "Unknown"
  end



  def to_s
    "Unknown Order"
  end

  def self.visible_order_for_theater_user(user)
    if user.is_theater_user?
      includes(performance: :production).where("(productions.theater_id in (:theater_ids)) OR orders.id in (select orders.id from orders, line_items, flex_pass_offers where line_items.order_id = orders.id and orders.type = 'FlexPassOrder' and line_items.flex_pass_offer_id = flex_pass_offers.id and flex_pass_offers.theater_id in (:theater_ids))", theater_ids: user.theater_ids).references(:productions)
    else
      where('1=1')
    end

  end

  def associated_theater_id
    nil
  end

  def sf
    if self.sf_object.nil?
      self.sf_object = SalesforceData::Event.find_by_stagemgr_order_id__c(self.id.to_s)
      if self.sf_object.nil?
        self.sf_last_sync_at = nil
        self.sync_to_salesforce!
      end
    end
    self.sf_object
  end

  # Transitions the order to the specified status.
  #
  # The method reflects a sequence of transitions, moving from one status
  # to another  in a predefined workflow. Each transition may involve specific
  # actions that need to be performed, such as sending notifications, updating
  # timestamps, or performing validations.
  #
  # @param new_status [Symbol] The desired status to transition to.
  # @raise [RuntimeError] If the transition is not allowed or fails.
  # @return [Boolean] True if the transition succeeds, false otherwise.
  #
  # @example Transition an order to :processed
  #   order = Order.find(1)
  #   order.transition_to!(Order::PROCESSED)
  #
  # Note: The method assumes that there is a logical sequence of statuses
  # and that each individual transition method 
  # (e.g., transition_new_to_processing! followed by transition_processing_to_processed!)
  # is defined to handle the specific logic required to move from one status to
  # the next in the sequence.

  def transition_to!(new_status)
    Order.transaction do
      begin
        old_status = self.status
        redirect_to = self.send "transition_#{self.status.underscore}_to_#{new_status.underscore}!".to_sym
        raise "Transition from #{old_status} to #{new_status} unsuccessful. Current status is #{self.status}." unless self.status == new_status
      rescue StandardError=>e
        Rails.logger.error "Order #{self.id} could not transition from #{old_status} to #{new_status}:"
        Rails.logger.error "   #{e.to_s}"
        Rails.logger.debug e.backtrace.join("\n")
        errors.add(:error, e.to_s)
        self.status = old_status
        self.id = nil if self.status.eql?(Order::NEW)
        raise e
      end
    end
    self
  end

  def status_display
    case self.status
      when HOLD
        "Held"
      else
        self.status
    end
  end

  def self.regularize_addresses
    orders = Order.all
    orders.each { |o|
      o.link_to_address_of_record
      if o.address_id_changed?
        begin
          o.save!
        rescue Exception => e
          puts(e)
        end
      end
    }
  end

  def transitory?
    TRANSITORY_STATUSES.include? self.status
  end

  def in_multi_transactional_state?
    status.eql?(Order::PROCESSING)
  end


  # All statuses that can be considered as "reserved" by a purchase
  # (used for determining flex pass availability for limited-by-production flex passes)
  #
  def self.non_reserving_statuses
    [Order::REFUNDED] + Order::UNPROCESSED_STATUSES
  end

  def unprocessed?
    UNPROCESSED_STATUSES.include? self.status
  end

  def self.delete_unprocessed_orders
    orders = Order.transitory.where("updated_at < :window and type != 'MembershipOrder'",
                         {:window=>Time.now - 20.minutes})
    orders.each do |order|
      order.destroy
    end

    orders = Order.transitory.where("updated_at < :window and type = 'MembershipOrder'",
                         {:window=>Time.now - 8.hours})
    orders.each do |order|
      order.destroy
    end

  end

  def self.fix_expiration_year(expiration_year)
    unless expiration_year.blank? || expiration_year.length > 2
      expiration_year = "20" + expiration_year
    end
    expiration_year
  end

  def link_to_address_of_record
    if !self.address.nil? then

      merge = self.address.find_original
      if !merge.nil? then
        comparison_id = self.address.id.nil? ? -1 : self.address.id
        if comparison_id != merge.id then
          merge.update_from(self.address)
          a = self.address
          self.address = merge
          merge.save!
          a.destroy unless a.nil? || (Order.where("id <> :id AND address_id = :address_id", id:self.id, address_id: a.id).count > 0)
        end
      end
    end
  end

  def last_processed_on
    self.payments.map {|p| p.processed_on}.max
  end

  def unique_line_items(reload_line_items = false)
    hack = Array.new
    unless special_offer_line_item.nil?
      hack << self.special_offer_line_item
    end
    hack
  end

  def all_line_items(reload_line_items = false)
    result = Array.new
    if reload_line_items
      special_offer_line_item.reload
      service_line_item.reload
    end
    result << self.special_offer_line_item unless self.special_offer_line_item.nil?
    result += self.service_line_items
    result.select{|r| !r.nil?}
  end

  def cancel_pending_tasks
    tasks.select(&:uncompleted?).each(&:cancel!)
  end

  private

  def self.trg_row(buyer_type, season, description, address)
    return [buyer_type, season, description, address.first_name, address.last_name, address.full_name, '', address.email,
            address.line1, address.line2, nil, address.city, address.state, address.zipcode, address.phone, address.id]
  end


  protected

  def balanced_transaction?
    li_total = total_due
    pay_total = total_paid
    return true if li_total.eql?(pay_total)

    errors.add(:status, "cannot be set to #{status} if the total ($#{li_total}) isn't countered by a payment (currently $#{pay_total}).")
    false
  end


  def status_is_provided?
    !self.status.blank?
  end

  
  def check_for_settled_payments
    paid_amt = self.total_paid || 0
    if (paid_amt > 0 && self.payments.select{|p| !p.can_cancel?}.size > 0)
      errors.add(:order,"Cannot destroy orders with settled payments") 
      return false
    else
      return true
    end
  end

  def prevent_status_rollbacks
    if self.status_changed? && !self.status_was.blank?
      self.errors.add(:error, "Cannot reprocess orders") if self.unprocessed? && !UNPROCESSED_STATUSES.include?(self.status_was)
    end
    true
  end


  def refund_line_items(reversing_entries)

  end

  def cascade_address_to_nested_items
    # code here
  end

  def create_credit_card_payment(amount)
    new_payment = CreditCardPayment.new(
        :amount => amount,
        :address => self.address,
        :card_number => self.credit_card_number,
        :card_expiration_month => self.credit_card_expiration_month,
        :card_expiration_year => self.credit_card_expiration_year,
        :card_type => self.credit_card_type,
        :card_verification_number => self.credit_card_verification_number,
        :confirmation_code => self.credit_card_confirmation_code,
        :ip_address => self.ip_address
    )
    payments << new_payment
    new_payment.process!
  end

  def preset_line_items

  end

  def transition_new_to_hold!(redirect_to = nil)
    self.status = Order::HOLD
    self.save!
    redirect_to
  end

  def transition_processed_to_processed!(redirect_to = nil)
    self.save!
    redirect_to
  end

  def transition_fulfilled_to_fulfilled!(redirect_to = nil)
    redirect_to
  end

  def transition_new_to_processed!(redirect_to = nil)
      self.transition_new_to_processing!(redirect_to)
      self.transition_processing_to_processed!(redirect_to)
  end

  def transition_new_to_processing!(redirect_to = nil)
    Order.transaction do
      self.status = Order::PROCESSING
      self.save!
      self.update_special_offer_line_item_from_code! unless self.special_offer_code.blank?
      self.save!
    end
    redirect_to
  end


  def transition_hold_to_processing!(redirect_to = nil)
    transition_new_to_processing!(redirect_to)
  end

  def transition_hold_to_processed!(redirect_to = nil)
    transition_new_to_processing!(redirect_to)
    transition_processing_to_processed!(redirect_to)
  end

  def transition_hold_to_hold!(redirect_to = nil)
    self.save!
    redirect_to
  end

  def transition_processing_to_processed!(redirect_to = nil)
    Order.transaction do
      if self.valid?
        self.update_special_offer_line_item_from_code! unless (self.special_offer_code.blank? || !self.special_offer_line_item.nil?)
        self.special_offer_line_item.special_offer.apply_to_order(self) unless special_offer_line_item.nil?
        create_proper_payment_in_amount_of!(self.total)
        self.status = Order::PROCESSED
        self.set_email_confirmation
        self.special_offer_line_item.mark_redeemed unless self.special_offer_line_item.nil?
        self.save!
        self.remove_suppressed_service_items
        save_additional_donation_order(self.additional_donation, Theater.default_theater) unless (self.additional_donation.blank? || self.additional_donation.to_i == 0)
        save_additional_donation_order(self.additional_donation_for_other) unless (self.additional_donation_for_other.blank? || self.additional_donation_for_other.to_i == 0)
      end
    end
    redirect_to
  end

  def transition_unclaimed_to_fulfilled!(redirect_to = nil)
    transition_processed_to_fulfilled!(redirect_to)
  end

  def transition_hold_to_fulfilled!(redirect_to = nil)
    redirect_to = transition_hold_to_processed!(redirect_to)
    transition_processed_to_fulfilled!
  end

  def transition_processed_to_fulfilled!(redirect_to = nil)
    self.status = Order::FULFILLED
    self.save!
    redirect_to
  end

  def self.allowed_for(user)
    result = Order.all
    result = result.where("orders.theater_id in (?)", user.theater_ids) if user.is_theater_user?
    result
  end

  #
  # delete service items that are suppressed for pass payments
  #
  def remove_suppressed_service_items
    if self.payment_type.is_a? PassPaymentType
      self.service_line_items.select{|sli| sli.suppress_for_pass_payments?}.each{|sli| sli.destroy}
    end
  end

  def create_recipient_address
      new_owner = Address.new(:full_name=>self.recipient_name, :email=>self.recipient_email)
      new_owner = new_owner.find_original || new_owner
      new_owner.save!
      self.recipient_address_id = new_owner.id
  end

  def set_defaults
    self.status ||= HOLD
    self.hold_under = self.address.full_name if self.hold_under.blank?
  end

  def create_mail_list_task
    if self.do_not_create_tasks.nil? && self.add_to_email_list == "1"
      self.tasks << MyEmmaTask.new(:execute_at=>Time.now + 5.minutes) if !self.address.email.nil?
    end
  end

  def create_receipt_task

  end

  def create_transfer_ownership_task
  end

  def create_notify_refund_task
  end

  def newly_canceled?
    self.status_changed? && [UNCLAIMED, CANCELED, REFUNDED, EXCHANGED].include?(self.status)
  end

  def set_tasks_after_save
    if self.do_not_create_tasks.nil? && (self.new_record? || self.saved_change_to_status?)
      case self.status
        when PROCESSED
          create_mail_list_task
          create_receipt_task
          create_transfer_ownership_task if self.gift?
      end
    end

  end

  
  def copy_payment_information(from_order)
    self.credit_card_number = from_order.credit_card_number
    self.credit_card_type = from_order.credit_card_type
    self.credit_card_expiration_year = from_order.credit_card_expiration_year
    self.credit_card_expiration_month = from_order.credit_card_expiration_month
    self.credit_card_confirmation_code = from_order.credit_card_confirmation_code
    self.credit_card_verification_number = from_order.credit_card_verification_number
    self.flex_pass_code = from_order.flex_pass_code
    self.member_code = from_order.member_code
  end

  private
  def auto_link_processed_to_address_of_record
    if status == Order::PROCESSED then
      link_to_address_of_record
    end
  end

  def save_additional_donation_order(donation_amount, credit_to_theater = nil)
    donation = DonationOrder.new(:address => self.address, :payment_type => self.payment_type, :status => Order::NEW)
    donation.copy_payment_information(self)
    donation.campaign = self.performance.production.name unless self.performance.nil?
    donation.theater = credit_to_theater.nil? ? self.theater : credit_to_theater
    donation.donation_line_items.build(:amount => donation_amount)
    donation.transition_to!(Order::PROCESSED)
  end

  protected # validation methods
  def set_uuid_on_create
    self.uuid ||= SecureRandom.uuid if new_record?
  end

  def cascade_address_to_nested_items
    # override as necessary in sub classes
  end

  # something about all the overloaded order/line items breaks the normal
  # pattern of << for service_line_item association
  # so we explicitly attach servie line items to the order
  def associate_service_line_items
    service_line_items.each { |sli| sli.order = self }
  end

  def set_defaults
    self.status ||= HOLD
    self.hold_under = address.full_name if hold_under.blank?
  end

  def create_recipient_address
    return unless gift?

    new_owner = Address.new(full_name: recipient_name, email: recipient_email)
    new_owner.save!
    new_owner = new_owner.find_original || new_owner
    self.recipient_address_id = new_owner.id
  end

  def link_to_address_of_record
    return unless status == PROCESSED

    if paid_with_membership?
      merge = membership_payments.first.membership.address
    else
      merge = address.find_original
    end

    return if merge.nil?

    comparison_id = address.id.nil? ? -1 : address.id
    if comparison_id != merge.id
      merge.update_from(address)
      self.address = merge
      merge.save!
      address.destroy unless address.nil? || Order.where.not(id: id).where(address_id: address.id).exists?
    end
  end


  def set_tasks_after_save
    return unless do_not_create_tasks.nil? && (new_record? || saved_change_to_status?)

    case status
    when PROCESSED
      create_mail_list_task
      create_receipt_task
      create_transfer_ownership_task if gift?
    end
  end

  private # these might be ghost methods...

  def payment_attributes
    {:credit_card_number=>self.credit_card_number,
     :credit_card_type=>self.credit_card_type,
     :credit_card_expiration_year=>self.credit_card_expiration_year,
     :credit_card_expiration_month=>self.credit_card_expiration_month,
     :credit_card_confirmation_code=>self.credit_card_confirmation_code,
     :card_verification_number => self.credit_card_verification_number,
     :flex_pass_code=>self.flex_pass_code,
     :ip_address => self.ip_address,
     :member_code=>self.member_code,
     :check_number=>self.check_number}
  end

  def time_to_hold_in_transition
    10.minutes
  end



end

