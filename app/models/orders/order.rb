require 'payment_form_fields'

InvalidSpecialOfferCode = Class.new(StandardError)

class Order < ActiveRecord::Base
  using_access_control

  include PaymentFormFields
  include Admin::ReportsHelper
  include ActionView::Helpers::NumberHelper

  extend HTMLDiff

  belongs_to :performance
  belongs_to :theater

  has_many :payments
  has_many :exchange_payments
  has_many :price_override_payments
  has_many :tasks, :class_name=>'OrderTask', :dependent=>:destroy

  has_many :line_items
  has_many :flex_pass_line_items
  has_many :special_offer_line_items

  belongs_to :address
  accepts_nested_attributes_for :flex_pass_line_items,
                                :special_offer_line_items,
                                :address,
                                :allow_destroy => true
  attr_accessor :special_offer_code
  attr_accessor :door_sale
  attr_accessor :additional_donation
  attr_accessor_with_default :email_confirmation, 0
  attr_accessor :add_to_email_list
  attr_accessor :do_not_create_tasks

  attr_accessor :credit_card_number,
                :credit_card_type,
                :credit_card_expiration_year,
                :credit_card_expiration_month,
                :credit_card_verification_number,
                :credit_card_confirmation_code,
                :credit_card_swipe,
                :flex_pass_code,
                :member_code

  def copy_payment_information(from_order)
    self.credit_card_number = from_order.credit_card_number
    self.credit_card_type = from_order.credit_card_type
    self.credit_card_expiration_year = from_order.credit_card_expiration_year
    self.credit_card_expiration_month = from_order.credit_card_expiration_month
    self.credit_card_confirmation_code = from_order.credit_card_confirmation_code
    self.credit_card_verification_number = from_order.credit_card_verification_number
    self.flex_pass_code = from_order.flex_pass_code

  end

  def payment_attributes
    {:credit_card_number=>self.credit_card_number,
     :credit_card_type=>self.credit_card_type,
     :credit_card_expiration_year=>self.credit_card_expiration_year,
     :credit_card_expiration_month=>self.credit_card_expiration_month,
     :credit_card_confirmation_code=>self.credit_card_confirmation_code,
     :flex_pass_code=>self.flex_pass_code,
     :member_code=>self.member_code}
  end


  ORDER_STATUSES = (
  HOLD, WEB, NEW, PROCESSING, PROCESSED, REFUNDED, EXCHANGED, FULFILLED, CANCELED, UNCLAIMED =
      "Hold", "Web", "New", "Processing", "Processed", "Refunded", "Exchanged", "Fulfilled", "Canceled", "Unclaimed")


  PAYMENT_TYPES = (
  CREDIT_CARD, CASH, FLEX_PASS, PRICE_OVERRIDE, MEMBERSHIP =
      "Credit Card", "Cash", "FlexPass", "Price Override", "Membership")

  REFERRALS = [
      "Email", "Mail", "Cast/Staff/Production Team", "Review/Feature", "Radio", "Newspaper Ad", "Facebook", "Twitter", "Word of Mouth", "Attended previous production", "Other"
  ]

  acts_as_audited


  before_validation :cascade_address_to_nested_items
  before_validation :initialize_nested_line_items, :on => :create
  before_validation :set_defaults

  after_validation :auto_link_processed_to_address_of_record
  before_save :set_theater
  after_save :set_tasks_after_save


  validates_inclusion_of :status, :in => ORDER_STATUSES, :if=>:status_is_provided?
  validates_inclusion_of :payment_type, :in => PAYMENT_TYPES

  validates_presence_of :address
  validates_associated :address,
                       :payments,
                       :flex_pass_line_items, :special_offer_line_items

  validates_each :status do |record, attr, value|

    if value == PROCESSED
      unless record.total == record.value_of_all_payments
        record.errors.add attr, "cannot be set to #{PROCESSED} if the total isn't countered by a payment."
      end
      m_payments = record.membership_payments
      m_payments.each { |p| p.membership.verify_applicable_for(record) }
    end
  end


  def value_of_all_payments
    self.unique_payments.sum { |p| p.amount }

  end

  def exchangeable?
    false
  end

  def fulfillable?
    self.status == Order::PROCESSED || self.status == Order::UNCLAIMED
  end

  def fulfilled?
    self.status == Order::FULFILLED
  end

  def self.attending_statuses
    [Order::PROCESSED, Order::FULFILLED]
  end

  def refundable?
    self.exchangeable?
  end

  def addresses
    [self.address]
  end

  def display_code()
    case
      when self.contains_flex_pass?
        "FLEXPASS"
    end
  end

  def total(reload_line_items=false)
    if (self.payments.nil?) || (self.payments.size == 0) then
      a = self.unique_line_items(reload_line_items).to_a.sum { |line_item|
        line_item.respond_to?(:total) ? line_item.total : 0
      }
    else
      a = self.payments.to_a.sum { |payment| payment.respond_to?(:amount) ? payment.amount : 0 }
    end
    a = 0.0 if a < 0.0
    a
  end

  def total_ticket_quantity
    0
  end

  def customer_visible_total(reload_line_items = false)
    self.payments.to_a.sum { |payment| payment.respond_to?(:customer_visible_amount) ? payment.customer_visible_amount : 0 }
  end

  def ticketing_fee
    self.line_items.uniq.to_a.sum { |li| li.respond_to?(:ticketing_fee) ? li.ticketing_fee : 0 }
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

  def contains_flex_pass?
    (self.line_items.select { |li| li.is_a? FlexPassLineItem }+self.flex_pass_line_items).size > 0
  end

  def flex_pass_offer
    FlexPassOffer.find(self.flex_pass_line_items[0].flex_pass_offer_id) unless self.flex_pass_line_items.size == 0
  end

  def valid_payment_types_for(current_user)
    valid_payment_types = Order::PAYMENT_TYPES.clone
    unless current_user && (current_user.is_administrator? || current_user.is_box_office_user?)
      valid_payment_types.delete CASH
      valid_payment_types.delete PRICE_OVERRIDE
    end
    if self.contains_flex_pass?
      valid_payment_types.delete FLEX_PASS
      valid_payment_types.delete MEMBERSHIP
    end
    valid_payment_types
  end

  def show_confirmation_for?(current_user)
    current_user && (current_user.is_administrator? || current_user.is_box_office_user?)
  end

  def editable?
    [HOLD, NEW, nil].include? self.status
  end

  def paid?
    [PROCESSED, FULFILLED, UNCLAIMED].include? self.status
  end

  def paid_with_currency?
    [CASH, CREDIT_CARD].include? self.payment_type
  end

  def paid_with_flexpass?
    FLEX_PASS == self.payment_type
  end

  def paid_with_flexpass
    unless flex_pass_payments.empty?
      FlexPass.find(flex_pass_payments.first.flex_pass_id)
    end
  end

  def using_credit_card?
    self.payment_type == Order::CREDIT_CARD && self.total > 0
  end

  def held?
    self.status == HOLD
  end

  def special_offer_code_used
    self.special_offer_line_items.empty? ? '' : self.special_offer_line_items.first.special_offer.code
  end

  def refund!

    Order.transaction do
      refund_payments = []
      self.payments.each { |payment| payment.refund!(nil, self.notes) if payment.respond_to? :refund! }
      self.unique_line_items.each { |li| li.refund! if li.respond_to? :refund! }
      self.status = REFUNDED
      save!
    end

  end

  def unclaimed!
    self.status = UNCLAIMED
    save!
  end

  def cancel!
    self.destroy
  end

  def create_proper_payment_in_amount_of!(amount)
    case self.payment_type
      when CASH
        new_payment = CashPayment.new(:amount => amount)
        self.payments << new_payment
      when CREDIT_CARD
        if (amount != 0) then
          create_credit_card_payment(amount)
        else
          new_payment = CashPayment.new(:amount => 0)
          payments << new_payment
        end
      when PRICE_OVERRIDE
        new_payment = self.price_override_payments.create!(:amount => amount)
      else
        raise 'New payment type not yet implemented.'
    end
    new_payment
  end

  def set_email_confirmation
    #now = DateTime.now
    #if !self.performance.nil? && (self.performance.performance_date > Date.today || (self.performance.performance_date == Date.today && self.performance.performance_time > Time.now - (60*60)))
    self.email_confirmation=1
    #end
  end

  def update_special_offer_line_items_from_code!
    if !self.special_offer_code.blank?
      self.special_offer_line_items.clear
      special_offer = SpecialOffer.find_by_order(self)
      if special_offer
        self.special_offer_line_items.create!(:special_offer=>special_offer)
      else
        raise "Unknown or expired special offer code \"#{self.special_offer_code}\""
      end
    end
  end

  def display_code
    self.contains_flex_pass? ? "FLEXPASS" : "DONATION"
  end

  def description
    case
      when self.contains_flex_pass?
        self.flex_pass_line_items[0].flex_pass_offer.name
      else
        "Unknown"
    end

  end

  def total_amount
    sum = self.payments.inject { |sum, x| sum + x.nil? ? 0 : x.amount }
    sum.amount unless sum.nil?
  end

  def set_form_defaults
    self.payment_type ||= CREDIT_CARD
  end

  def to_s
    case

      when self.contains_flex_pass?
        self.flex_pass_line_items[0].to_s
      else
        ""
    end

  end

  def transition_to!(new_status, redirect_to = nil)
    old_status = self.status
    redirect_to = self.send "transition_#{self.status.underscore}_to_#{new_status.underscore}!".to_sym, redirect_to
    raise "Transition from #{old_status} to #{new_status} unsuccessful. Current status is #{self.status}." unless self.status == new_status
    redirect_to
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

  def self.send_flex_pass_reminder
    email = $EMAIL_ADDRESS['flex_pass_notifications']

    unless email.blank?
      flex_pass_orders = Order.all(:conditions=>["line_items.type = 'FlexPassLineItem' and status = ?", Order::PROCESSED], :include => :line_items)
      OrderMailer.send(:flex_pass_pending_reminder, flex_pass_orders).deliver
    end
  end

  def self.delete_unprocessed_orders
    orders = Order.where("status in (:transitory_status) and updated_at < :window and type != 'MembershipOrder'",
                         {:transitory_status=>self.transitory_statuses,
                          :window=>Time.now - 1.hour})
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


  def paid_with_pass?
    self.payment_type == Order::FLEX_PASS || !self.flex_pass_payments.empty?
  end


  def paid_with_membership?
    !self.membership_payments.empty?
  end


  def link_to_address_of_record
    if !self.address.nil? then
      self.address.regularize!

      merge = self.address.find_original
      if !merge.nil? then
        merge.update_from(self.address)
        a = self.address
        self.address = merge
        a.destroy if !a.nil?
      end
    end
  end

  def self.export_trg_dump
    FasterCSV.open("/tmp/trg_dump.csv", "w") do |csv|
      orders = TicketOrder.order(:performance_id).includes(:address, :theater, :payments, {:performance, :production})
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

      orders = MembershipOrder.includes(:address, {:membership_line_items, :membership})

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

  private


  def self.trg_row(buyer_type, season, description, address)
    return [buyer_type, season, description, address.first_name, address.last_name, address.full_name, '', address.email,
            address.line1, address.line2, nil, address.city, address.state, address.zipcode, address.phone, address.id]
  end

  protected

  def set_theater
    if self.contains_flex_pass?
      self.theater_id = self.flex_pass_line_items[0].flex_pass_offer.theater_id
    end
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

  def all_line_items(reload_line_items = false)
    self.line_items(reload_line_items) + self.special_offer_line_items(reload_line_items) +
        self.flex_pass_line_items(reload_line_items)
  end

  def unique_line_items(reload_line_items = false)
    self.all_line_items(reload_line_items).uniq
  end

  def unique_payments
    (self.payments.to_a
    self.exchange_payments +
        self.price_override_payments).uniq
  end

  def transition_new_to_hold!(redirect_to = nil)
    self.status = Order::HOLD
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
      self.update_special_offer_line_items_from_code! unless self.special_offer_code.blank?
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

      self.special_offer_line_items.each { |li| li.special_offer.apply_to_order(self) }
      create_proper_payment_in_amount_of!(self.total)
      self.status = Order::PROCESSED
      self.set_email_confirmation
      self.special_offer_line_items.each { |li| li.mark_redeemed }
      self.save!
    end
    save_additional_donation_order unless (self.additional_donation.blank? || self.additional_donation.to_i == 0)
    redirect_to
  end

  def transition_unclaimed_to_fulfilled!(redirect_to = nil)
    transition_processed_to_fulfilled!(redirect_to)
  end

  def transition_processed_to_fulfilled!(redirect_to = nil)
    self.status = Order::FULFILLED
    self.save!
    redirect_to
  end

  def set_defaults
    self.status ||= HOLD
    set_form_defaults
    self.flex_pass_line_items.each { |tli| tli.order=self }
  end

  def create_mail_list_task
    self.tasks << MyEmmaTask.new(:execute_at=>Time.now + 5.minutes) if !self.address.email.nil?
  end


  def create_receipt_task
    self.tasks << OutreachTask.new(:execute_at=>Time.now + 5.minutes, :method_symbol=>:flexpass_confirmation) if self.contains_flex_pass?
  end


  def set_tasks_after_save
    if self.do_not_create_tasks.nil? && self.status_changed?
      case self.status
        when PROCESSED
          create_mail_list_task if (self.add_to_email_list == "1")
          create_receipt_task
        when UNCLAIMED, CANCELED, REFUNDED, EXCHANGED
          cancel_pending_tasks
      end
    end

  end


  def cancel_pending_tasks
    self.tasks.select { |t| t.uncompleted? }.each { |t| t.cancel! }
  end


  private
  def auto_link_processed_to_address_of_record
    if status == Order::PROCESSED then
      link_to_address_of_record
    end
  end


  def initialize_nested_line_items
    line_items.each { |li| li.order = self }
  end

  def save_additional_donation_order
    donation = DonationOrder.new(:address => self.address, :payment_type => self.payment_type, :status => Order::PROCESSING)
    donation.copy_payment_information(self)
    donation.save!

    donation.donation_line_items.build(:donation_amount => self.additional_donation)
    donation.transition_to!(Order::PROCESSED)

  end


end
