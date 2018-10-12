require 'payment_form_fields'

InvalidSpecialOfferCode = Class.new(StandardError)

class Order < ActiveRecord::Base

  include PaymentFormFields
  include Admin::ReportsHelper
  include ActionView::Helpers::NumberHelper
  include EmailValidatable

  extend HTMLDiff

  belongs_to :performance
  belongs_to :theater
  belongs_to :payment_type

  has_many :payments
  has_many :exchange_payments
  has_many :price_override_payments
  has_many :tasks, :class_name=>'OrderTask', :dependent=>:destroy
  has_many :seats, foreign_key: :order_id, class_name: 'SeatAssignment'
  has_one :special_offer_line_item

  belongs_to :address
  belongs_to :recipient_address, :class_name=>:address, :foreign_key=>:recipient_address_id

  accepts_nested_attributes_for :special_offer_line_item,
                                :address,
                                :allow_destroy => true
  attr_accessor :special_offer_code
  attr_accessor :door_sale
  attr_accessor :additional_donation
  attr_accessor :email_confirmation
  attr_accessor :add_to_email_list
  attr_accessor :do_not_create_tasks
  attr_accessor :give_gift_on_month, :give_gift_on_day

  attr_accessor :credit_card_number,
                :credit_card_type,
                :credit_card_expiration_year,
                :credit_card_expiration_month,
                :credit_card_verification_number,
                :credit_card_confirmation_code,
                :credit_card_swipe,
                :flex_pass_code,
                :member_code,
                :check_number
  attr_accessor :sf_object


  ORDER_STATUSES = (
  HOLD, NEW, PROCESSING, PROCESSED, REFUNDED, EXCHANGED, EXCHANGING, RELEASING, FULFILLED, CANCELED, UNCLAIMED =
      "Hold", "New", "Processing", "Processed", "Refunded", "Exchanged", "Exchanging", "Releasing", "Fulfilled", "Canceled", "Unclaimed")

  HOLDING_SEAT_STATUSES = [HOLD, PROCESSING, PROCESSED, EXCHANGING, RELEASING, FULFILLED]

  REFERRALS = [
      "Email", "Mail", "Cast/Staff/Production Team", "Review/Feature", "Radio", "Newspaper Ad", "Facebook", "Twitter", "Word of Mouth", "Attended previous production", "Other"
  ]

  audited


  before_validation :cascade_address_to_nested_items
  before_validation :set_defaults
  before_validation :create_recipient_address, :if=>:gift?

  before_save :link_to_address_of_record, :if=>[:status_changed?, :processed?]
  after_validation :prevent_status_rollbacks
  before_destroy :check_for_settled_payments
  before_save :set_theater
  before_save :cancel_pending_tasks, :if=>:newly_canceled?
  after_save :set_tasks_after_save

  validates_inclusion_of :status, :in => ORDER_STATUSES, :if=>:status_is_provided?

  validates_presence_of :address
  validates_associated :address,
                       :payments,
                       :special_offer_line_item
  validates :hold_under, not_email: true

  before_save :is_balanced_transaction?, :if=>[:status_changed?, :processed?]
  validates_each :status do |record, attr, value|
    if value == PROCESSED
      m_payments = record.payments.select{|p| p.is_a? MembershipPayment}
      m_payments.each { |p| p.membership.verify_applicable_for(record) }
    end
  end

  def is_balanced_transaction?
    li_total = self.value_of_all_line_items
    pay_total = self.value_of_all_payments
    unless li_total == pay_total
      errors.add :status, "cannot be set to #{self.status} if the total ($#{li_total}) isn't countered by a payment (currently $#{pay_total})."
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

  def value_of_all_payments
    self.payments.sum(:amount)
  end

  def value_of_all_line_items
    a = self.all_line_items.to_a.sum { |line_item|
        line_item.respond_to?(:total) ? line_item.total : 0
      }
    a = 0.0 if a < 0.0
    a
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
    self.status == Order::PROCESSED || self.status == Order::UNCLAIMED
  end

  def fulfilled?
    self.status == Order::FULFILLED
  end

  def refunded?
    self.status == Order::REFUNDED
  end

  def printable?
    false
  end

  def time_to_hold_in_transition
    10.minutes
  end

  def self.attending_statuses
    [Order::PROCESSED, Order::FULFILLED]
  end

  def new?
    self.status == Order::NEW
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

  def total(reload_line_items=false)
    if (self.payments.nil?) || (self.payments.size == 0) then
      a = self.all_line_items.to_a.sum { |line_item|
        line_item.respond_to?(:total) ? line_item.total : 0
      }
    else
      a = self.value_of_all_payments
    end
    a = 0.0 if a < 0.0
    a
  end

  def number_of_tickets
    0
  end

  def ticketing_fee
    BigDecimal.new("0", 2)
  end

  def customer_visible_total(reload_line_items = false)
    total = self.payments.to_a.sum { |payment| payment.customer_visible_amount }
    total = 0 if (total.nil? || total < 0)
    total
  end


  def status_is_provided?
    !self.status.blank?
  end

  def membership_payments
    payments.select { |p| p.is_a? MembershipPayment }
  end

  def flex_pass_payments
    payments.select { |p| p.is_a? FlexPassPayment }
  end

  def credit_card_processing_fee
    fee = 0
    self.payments.each { |p| fee += p.processing_fee unless p.processing_fee.nil? }
    fee
  end

  def valid_payment_types_for(current_user)
    PaymentType.valid_payment_types_for(current_user)
  end

  def show_confirmation_for?(current_user)
    current_user && (current_user.is_administrator? || current_user.is_box_office_user?)
  end

  def processing?
    PROCESSING == self.status
  end


  def editable?
    [HOLD, NEW, PROCESSING, nil].include? self.status
  end

  def finalized?
    self.finalized_statuses.include? self.status
  end

  def paid?
    self.finalized?
  end

  def unsettled?
    !self.settled?
  end

  def settled?
    self.settled_statuses.include? self.status
  end

  def settled_statuses
    Order.settled_statuses
  end

  def self.settled_statuses
    [PROCESSED, FULFILLED, UNCLAIMED, REFUNDED, EXCHANGED]
  end

  def self.syncable_statuses
    return Order.finalized_statuses + [UNCLAIMED, REFUNDED, EXCHANGED]
  end

  def syncable_statuses
    return Order.syncable_statuses
  end

  def self.attended_statuses
    [PROCESSED, FULFILLED]
  end

  def attended_statuses
    Order.attended_statuses
  end

  def self.finalized_statuses
    self.attended_statuses + [UNCLAIMED]
  end

  def finalized_statuses
    Order.finalized_statuses
  end

  def processed?
    PROCESSED == self.status
  end

  def returned?
    [UNCLAIMED, REFUNDED, EXCHANGED].include? self.status
  end

  def unclaimed?
    self.status == UNCLAIMED
  end

  def attended?
    self.attended_statuses.include? self.status
  end

  def paid_with_currency?
    self.payment_type.is_a? CurrencyPaymentType
  end

  def paid_with_flexpass?
    self.payment_type.is_a?(FlexPassPaymentType) && !self.flex_pass_payments.empty?
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

  def self.held_statuses
    [Order::HOLD]
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
      refund_payments = []
      create_notify_refund_task if self.fulfilled?
      build_refunds = self.payments.dup
      build_refunds.each { |payment| payment.refund!(nil, self.notes) if payment.respond_to? :refund! }
      self.unique_line_items.each { |li| self.refund_line_items (li.refund!) if li.respond_to? :refund!  }
      self.status = REFUNDED
      self.save!
    end

  end

  def unclaimed!
    self.status = UNCLAIMED
    save!
  end

  def cancel!
    self.destroy
  end

  public

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
    unless self.special_offer_code.blank?
      special_offer = SpecialOffer.find_by_order(self)
      unless special_offer.nil?
        if self.special_offer_line_item.nil?
          self.build_special_offer_line_item(:special_offer=>special_offer)
        else
          self.special_offer_line_item.special_offer=special_offer
        end
      else
        raise RuntimeError, "Unknown or expired special offer code \"#{self.special_offer_code}\""
      end
    end
  end

  def description
    "Unknown"
  end

  def total_paid
    sum = self.payments.map{|p| p.amount}.inject(0) { |sum, x| sum + (x.nil? ? 0 : x) }
    sum unless sum.nil?
  end

  def total_amount
    self.total_paid
  end

  def to_s
    "Unknown Order"
  end

  def self.visible_order_for_theater_user(user)
    if user.is_theater_user?
      joins(performance: :production).where(productions: { theater_id:  user.theater_ids}).references(:productions)
    else
      where('1=1')
    end

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

  # using introspection, transition current status to new_status
  # Throws an exception if object cannot be transitioned, and sets error in the object
  # @new_status  [String]  New status (as defined in order.rb)

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
        errors.add :error, e.to_s
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

  def self.transitory_statuses
    [Order::NEW, Order::PROCESSING]
  end

  def transitory_statuses
    Order.transitory_statuses
  end

  def transitory?
    self.transitory_statuses.include? self.status
  end

  def in_transactional_state?
    status.eql?(Order::PROCESSING)
  end

  def self.unprocessed_statuses
    [Order::HOLD] + self.transitory_statuses
  end

  def unprocessed_statuses
    Order.unprocessed_statuses
  end

  def unprocessed?
    self.unprocessed_statuses.include? self.status
  end

  def self.delete_unprocessed_orders
    orders = Order.where("status in (:transitory_status) and updated_at < :window and type != 'MembershipOrder'",
                         {:transitory_status=>self.transitory_statuses,
                          :window=>Time.now - 20.minutes})
    orders.each do |order|
      order.destroy
    end

    orders = Order.where("status in (:transitory_status) and updated_at < :window and type = 'MembershipOrder'",
                         {:transitory_status=>self.transitory_statuses,
                          :window=>Time.now - 8.hours})
    orders.each do |order|
      order.destroy
    end

  end

  def paid_with_membership?
    !self.membership_payments.empty?
  end

  def self.fix_expiration_year(expiration_year)
    unless expiration_year.blank? || expiration_year.length > 2
      expiration_year = "20" + expiration_year
    end
    expiration_year
  end

  def link_to_address_of_record
    if !self.address.nil? then

      if self.paid_with_membership? then
        merge = membership_payments.first.membership.address
      else
        merge = self.address.find_original
      end
      if !merge.nil? then
        comparison_id = self.address.id.nil? ? -1 : self.address.id
        if comparison_id != merge.id then
          merge.update_from(self.address)
          a = self.address
          self.address = merge
          merge.save!
          a.destroy unless a.nil? || a.has_finalized_orders?
        end
      end
    end
  end

  def self.export_trg_dump
    FasterCSV.open("/tmp/trg_dump.csv", "w") do |csv|
      orders = TicketOrder.order(:performance_id).includes(:address, :theater, :payments, {:performance=>:production})
      report = Array.new
      headers = [:buyer_type, :year, :description, :first, :last, :full_name, :company, :email, :address1, :address2,
                 :address3, :city, :state, :zip, :home_phone, :business_phone, :patron_id]
      csv << headers
      orders.each do |order|
        puts "Processing order ##{order.id}"
        if order.performance.performance_date <= Date.today && order.paid? && order.address.contactable?

          buyer_type = case
            when order.paid_with_membership?
              'MEM'
            when order.theater.is_default?
              order.total == 0 ? 'CMP' : 'STB'
            else
              'REN'
          end

          season_tag = order.performance.production.season - 1 unless order.performance.production.season.blank?
          season_text = "#{season_tag.to_s[2..3]}-#{(season_tag+1).to_s[2..3]}"

          description = "#{season_text} #{buyer_type}: #{order.performance.production.name}"
          csv << trg_row(buyer_type, order.performance.production.season, description, order.address)

          description = "#{season_text} FULL: Building Attendee"
          csv << trg_row(buyer_type, order.performance.production.season, description, order.address)

          if order.theater.is_resident?
            description = "#{season_text} FULL: Resident Company Attendee"
            csv << trg_row(buyer_type, order.performance.production.season, description, order.address)
          end

          if order.theater.is_default?
            description = "#{season_text} FULL: #{order.theater.name} Attendee"
            csv << trg_row(buyer_type, order.performance.production.season, description, order.address)
          end
        end

      end

      orders = MembershipOrder.includes(:address, {:membership_line_item=>:membership})

      orders.each do |order|
        description = "#{order.membership.member_since.year} MEM: #{order.membership.membership_offer.name}"
        csv << trg_row('DNT', order.membership.member_since.year, description, order.address)
      end

      orders = DonationOrder.includes(:address)

      orders.each do |order|
        description = "#{order.created_at.year} Donor"
        csv << trg_row('DNT', order.created_at.year, description, order.address)
      end
    end

    nil
  end

  def last_processed_on
    self.payments.map {|p| p.processed_on}.max
  end

  def unique_line_items(reload_line_items = false)
    hack = Array.new
    unless special_offer_line_item.nil?
      hack << self.special_offer_line_item(reload_line_items)
    end
    hack
  end

  def all_line_items(reload_line_items = false)
    result = Array.new
    result << self.special_offer_line_item(reload_line_items)
  end


  def cancel_pending_tasks
    self.tasks.select { |t| t.uncompleted? }.each { |t| t.cancel! }
  end



  private

  def self.trg_row(buyer_type, season, description, address)
    return [buyer_type, season, description, address.first_name, address.last_name, address.full_name, '', address.email,
            address.line1, address.line2, nil, address.city, address.state, address.zipcode, address.phone, address.id]
  end

  protected


  def set_theater

  end

  def check_for_settled_payments
    paid_amt = self.total_paid || 0
    raise "Cannot destroy orders with settled payments" if (paid_amt > 0 && self.payments.select{|p| !p.can_cancel?}.size > 0)
    true
  end

  def prevent_status_rollbacks
    if self.status_changed? && !self.status_was.blank?
      self.errors.add(:error, "Cannot reprocess orders") if Order.unprocessed_statuses.include?(self.status) && !Order.unprocessed_statuses.include?(self.status_was)
      return false
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

  def unique_payments
    (self.payments.to_a +
    self.exchange_payments +
        self.price_override_payments).uniq
  end

  def preset_line_items

  end

  def transition_new_to_hold!(redirect_to = nil)
    self.status = Order::HOLD
    self.save!
    redirect_to
  end

  def transition_processed_to_processed!(redirect_to)
    self.save!
    redirect_to
  end

  def transition_new_to_processed!(redirect_to = nil)
      transition_new_to_processing!(redirect_to)
      transition_processing_to_processed!(redirect_to)
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
      self.update_special_offer_line_item_from_code! unless (self.special_offer_code.blank? || !self.special_offer_line_item.nil?)
      self.special_offer_line_item.special_offer.apply_to_order(self) unless special_offer_line_item.nil?
      create_proper_payment_in_amount_of!(self.total)
      self.status = Order::PROCESSED
      self.set_email_confirmation
      self.special_offer_line_item.mark_redeemed unless self.special_offer_line_item.nil?
      self.save!
      save_additional_donation_order unless (self.additional_donation.blank? || self.additional_donation.to_i == 0)
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
    if (self.add_to_email_list == "1")
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
    if self.do_not_create_tasks.nil? && self.status_changed?
      case self.status
        when PROCESSED
          create_mail_list_task
          create_receipt_task
          create_transfer_ownership_task if self.gift?
      end
    end

  end

  private
  def auto_link_processed_to_address_of_record
    if status == Order::PROCESSED then
      link_to_address_of_record
    end
  end

  def save_additional_donation_order
    donation = DonationOrder.new(:address => self.address, :payment_type => self.payment_type, :status => Order::NEW)
    donation.copy_payment_information(self)
    donation.save!

    donation.donation_line_items.build(:donation_amount => self.additional_donation)
    donation.transition_to!(Order::PROCESSED)

  end


end

# Salesforce extension

class Order

  attr_writer :sf_disable_sync_on_commit

  def sf_disable_sync_on_commit?
    @sf_disable_sync_on_commit.nil? ? false : @sf_disable_sync_on_commit
  end

  after_commit :queue_sf_sync, :if=>Proc.new { |syncable| self.syncable? && !syncable.sf_disable_sync_on_commit? && SalesforceSync.enabled? }

  def queue_sf_sync(delay = nil)

  end

  def syncable?
    self.syncable_statuses.include?(self.status) && self.address.customer?
  end

end

