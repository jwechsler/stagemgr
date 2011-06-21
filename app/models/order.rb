require 'payment_form_fields'

InvalidSpecialOfferCode = Class.new(StandardError)

class Order < ActiveRecord::Base
  using_access_control

  include PaymentFormFields
  include ActionView::Helpers::NumberHelper
  after_validation :auto_link_processed_to_address_of_record
  before_save :set_theater
  extend HTMLDiff

  belongs_to :performance
  belongs_to :theater

  has_many :payments
  has_many :credit_card_payments
  has_many :cash_payments
  has_many :flex_pass_payments
  has_many :exchange_payments
  has_many :price_override_payments

  has_many :line_items
  has_many :ticket_line_items
  has_many :flex_pass_line_items
  has_many :special_offer_line_items
  has_many :donation_line_items
  belongs_to :address
  accepts_nested_attributes_for :line_items,
                                :ticket_line_items,
                                :flex_pass_line_items,
                                :special_offer_line_items,
                                :donation_line_items,
                                :address,
                                :payments,
                                :cash_payments,
                                :credit_card_payments, :allow_destroy => true
  attr_accessor :special_offer_code
  attr_accessor :door_sale
  attr_accessor :additional_donation
  attr_accessor_with_default :email_confirmation, 0

  ORDER_STATUSES = (
  HOLD, WEB, NEW, PROCESSING, PROCESSED, REFUNDED, EXCHANGED, FULFILLED, CANCELED, UNCLAIMED =
    "Hold", "Web", "New", "Processing", "Processed", "Refunded", "Exchanged", "Fulfilled", "Canceled", "Unclaimed")


  PAYMENT_TYPES = (
  CREDIT_CARD, CASH, FLEX_PASS, PRICE_OVERRIDE =
    "Credit Card", "Cash", "FlexPass", "Price Override")

  acts_as_audited

  validates_inclusion_of :status, :in => ORDER_STATUSES
  validates_inclusion_of :payment_type, :in => PAYMENT_TYPES

  validates_presence_of :address, :status
  validates_associated :address,
                       :payments, :credit_card_payments, :cash_payments,
                       :line_items, :ticket_line_items, :donation_line_items, :flex_pass_line_items, :special_offer_line_items

  before_validation :initialize_nested_line_items, :on => :create
  before_validation :set_defaults

  validates_each :status do |record, attr, value|
    if value == PROCESSED
      unless record.total == record.value_of_all_payments || record.ticket_quantity == record.number_of_tickets_of_all_payments
        record.errors.add attr, "cannot be set to #{PROCESSED} if the total isn't countered by a payment."
      end
      unless record.ticket_line_items.empty? || record.ticket_quantity > 0
        record.errors.add :ticket_line_items, "must contain at least one ticket."
      end
    end
  end


  def attended?
    [PROCESSED, FULFILLED].include?(self.status)
  end

  def value_of_all_payments
    all_payments = self.payments.to_a +
      self.credit_card_payments.to_a +
      self.cash_payments.to_a +
      self.exchange_payments.to_a +
      self.price_override_payments.to_a
    all_payments = all_payments.uniq
    all_payments.sum { |p| p.amount }
  end

  def number_of_tickets_of_all_payments
    self.flex_pass_payments.to_a.sum { |fpp| fpp.number_of_tickets }
  end

  def exchangeable?
    self.status == Order::PROCESSED || self.status == Order::FULFILLED
  end

  def fulfillable?
    self.status == Order::PROCESSED
  end

  def refundable?
    self.status == Order::PROCESSED || self.status == Order::FULFILLED
  end

  def addresses
    [self.address]
  end

  def production_code=(string)
    @prodution_code=string
  end

  def production_code()
    self.performance.try(:production).try(:production_code) || @production_code
  end

  def performance_code=(string)
    self.performance = Performance.find_by_performance_code(string)
  end

  def performance_code()
    case when self.contains_flex_pass?
           "FLEXPASS"
      when self.contains_donation?
        "DONATION"
      else
        self.performance.try(:performance_code)
    end
  end

  def ticket_quantity_by_class(class_code)
    self.ticket_line_items.to_a.sum { |li| li.ticket_class.class_code == class_code ? li.ticket_count : 0 }

  end
  def total(reload_line_items=false)
    if self.payments.blank? then
      (self.line_items(reload_line_items) +
        self.ticket_line_items(reload_line_items) +
        self.special_offer_line_items(reload_line_items) +
        self.flex_pass_line_items(reload_line_items) +
        self.donation_line_items(reload_line_items)
      ).uniq.to_a.sum { |line_item| line_item.respond_to?(:total) ? line_item.total : 0 }
    else
      self.payments.to_a.sum { |payment| payment.respond_to?(:amount) ? payment.amount : 0 }
    end
  end

  def ticketing_fee
    self.line_items.uniq.to_a.sum { |li| li.respond_to?(:ticketing_fee) ? li.ticketing_fee : 0 }
  end

  def credit_card_processing_fee
    processing_fee = self.credit_card_payments.to_a.sum { |payment| payment.amount * 0.04 }
    processing_fee += 0.22 if processing_fee > 0
    processing_fee
  end

  def ticket_quantity
    self.ticket_line_items(false).uniq.to_a.sum { |li| li.respond_to?(:ticket_count) ? li.ticket_count : 0 }
  end

  def contains_flex_pass?
    (self.line_items.select { |li| li.is_a? FlexPassLineItem }+self.flex_pass_line_items).size > 0
  end

  def contains_tickets?
    (self.line_items.select { |li| (li.is_a? TicketLineItem) && (li.ticket_count > 0) } + self.ticket_line_items.select { |li| li.ticket_count > 0 }).size > 0
  end

  def contains_donation?
    (self.donation_line_items.select { |li| (li.is_a? DonationLineItem) } + self.donation_line_items.select { |li| li.donation_amount > 0 }).size > 0
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
    if self.contains_flex_pass? || self.contains_donation?
      valid_payment_types.delete FLEX_PASS
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

  def held?
    self.status == HOLD
  end

  def full_name
    "#{self.first_name} #{self.last_name}"
  end

  def refund!

    Order.transaction do
      self.payments.each { |payment| payment.refund!(nil, self.notes) if payment.respond_to? :refund! }
      self.line_items.each { |li| li.refund! if li.respond_to? :refund! }
      self.status = REFUNDED
      save!
    end

  end

  def cancel!
    Order.delete(self.id)
  end

  def exchange_and_process_from!(original_order)
    Order.transaction do
      self.address = original_order.address
      original_order.status = Order::EXCHANGED
      self.save!
      self.update_special_offer_line_items_from_code!

      exchange_payment_on_original_order = original_order.exchange_payments.create!(:amount=>-1*original_order.payments(true).to_a.sum { |p| p.amount }, :note=>original_order.description)
      exchange_payment_on_self = self.exchange_payments.create!(:amount=>-1 * exchange_payment_on_original_order.amount, :payment_id=>exchange_payment_on_original_order.id)
      exchange_payment_on_original_order.update_attribute(:payment_id, exchange_payment_on_self.id)
      payment_difference = self.total - exchange_payment_on_self.amount
      if payment_difference < 0
        self.price_override_payments.create!(:amount=>payment_difference)
      elsif payment_difference > 0
        create_proper_payment_in_amount_of!(payment_difference)
      end
      self.status=Order::PROCESSED
      self.set_email_confirmation
      self.payments(true)
      self.save!
      original_order.release_tickets!
      original_order.save!
    end
  end

  def create_proper_payment_in_amount_of!(amount)
    case self.payment_type
      when CASH
        self.cash_payments.create!(:amount => amount)
      when CREDIT_CARD
        if (amount != 0) then
          new_payment = self.credit_card_payments.build(
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
          new_payment.process!
        else
          self.cash_payments.create(:amount => 0);
        end
      when FLEX_PASS
        flex_pass = FlexPass.find_by_code(self.flex_pass_code)
        raise 'No FlexPass with that code exists' unless flex_pass
        offer = flex_pass.flex_pass_offer
        if !offer.theater_id.blank? then
          raise "That FlexPass is restricted to #{Theater.find_by_id(offer.theater_id).name} productions" if (offer.theater_id != self.performance.production.theater.id and !offer.exclude_theater?)
          raise "That Flexpass cannot be used for tickets for #{Theater.find_by_id(flex_pass.flex_pass_offer.theater_id).name} productions" if (flex_pass.flex_pass_offer.theater_id == self.performance.production.theater.id and flex_pass.flex_pass_offer.exclude_theater?)

        end
        new_payment = self.flex_pass_payments.create!(
          :number_of_tickets => self.ticket_quantity,
          :flex_pass => flex_pass,
          :amount => flex_pass.flex_pass_offer.payout_per_ticket * self.ticket_quantity
        )
      when PRICE_OVERRIDE
        self.price_override_payments.create!(:amount => amount)
      else
        raise 'New payment type not yet implemented.'
    end
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
      special_offer = SpecialOffer.find(:first,
                                        :conditions => ["trim(lower(code)) = trim(lower(?)) and (performance_id = ? or production_id = ? or theater_id = ? or (performance_id is null and production_id is null and theater_id is null))",
                                                        self.special_offer_code,
                                                        self.performance.id,
                                                        self.performance.production.id,
                                                        self.performance.production.theater.id],
                                        :order=>"performance_id desc, production_id desc, theater_id desc")
      if special_offer
        self.special_offer_line_items.create!(:special_offer=>special_offer)
      else
        raise "Unknown special offer code \"#{self.special_offer_code}\""
      end
    end
  end

  def display_code
    self.contains_flex_pass? ? "FLEXPASS" : "NOPE"
    # performance.performance_code
  end

  def description
    case
      when self.contains_tickets?
        performance_s = self.performance.nil_or.to_short_s
        "#{performance_s} (#{self.ticket_detail_description})"
      when self.contains_donation?
        sum = self.donation_line_items.inject{|sum,x| sum + x.donation_amount}
        "Donation"
      when self.contains_flex_pass?
        self.flex_pass_line_items[0].flex_pass_offer.name
      else
        ""
    end

  end

  def total_amount
    sum = self.payments.inject {|sum,x| sum + x.nil? ? 0 : x.amount}
    sum.amount unless sum.nil?
  end

  def set_form_defaults
    self.payment_type ||= CREDIT_CARD
  end

  def to_s
    case
      when self.contains_tickets?
        self.ticket_detail_description
      when self.contains_donation?
        "Donation"
      when self.contains_flex_pass?
        self.flex_pass_line_items[0].to_s
      else
        ""
    end

  end


  def ticket_detail_description
    self.ticket_line_items.map { |li|
      if li.ticket_count > 0
        li.to_s
      else
        ""
      end
    }.join(', ')
  end

  def transition_to!(new_status)
    old_status = self.status
    self.send "transition_#{self.status.underscore}_to_#{new_status.underscore}!".to_sym
    raise "Transition from #{old_status} to #{new_status} unsuccessful. Current status is #{self.status}." unless self.status == new_status
  end

  def status_display
    case self.status
      when HOLD
        "Held"
      else
        self.status
    end
  end

  def release_tickets!
    ticket_line_items.each { |ti| TicketLineItem.delete(ti.id) }
  end

  def link_to_address_of_record
    if !self.address.nil?  then
      self.address.regularize!

      merge = self.address.find_original
      if !merge.nil? then
        merge.update_from!(self.address)
        a = self.address
        self.address = merge
      end
    end
  end

  private

  def auto_link_processed_to_address_of_record
     if status == Order::PROCESSED then
       link_to_address_of_record
     end
  end

  def transition_new_to_hold!
    self.status = Order::HOLD
    self.save!
  end

  def transition_new_to_processing!
    self.status = Order::PROCESSING
    self.save!
  end

  def transition_hold_to_processing!
    transition_new_to_processing!
  end

  def transition_hold_to_hold!
    self.save!
  end

  def transition_processing_to_processed!
    self.update_special_offer_line_items_from_code! unless self.special_offer_code.blank?

    create_proper_payment_in_amount_of!(self.total)

    save_additional_donation_order unless (self.additional_donation.blank? || self.additional_donation.to_i == 0)

    self.status = Order::PROCESSED
    self.set_email_confirmation
    self.save!
  end

  def transition_processed_to_fulfilled!
    self.status = Order::FULFILLED
    self.save!
  end

  def initialize_nested_line_items
    line_items.each { |li| li.order = self }
  end

  def set_defaults
    self.status ||= HOLD
    set_form_defaults
    self.ticket_line_items.each { |tli| tli.order=self }
    self.flex_pass_line_items.each { |tli| tli.order=self }
    self.donation_line_items.each { |di| di.order=self }
  end

  def save_additional_donation_order
    donation = Order.new(:address => self.address, :payment_type => self.payment_type, :status => Order::PROCESSING)
    donation.copy_payment_information(self)
    donation.save!

    donation.donation_line_items.build(:donation_amount => self.additional_donation)
    donation.transition_to!(Order::PROCESSED)

  end

  def set_theater
    if !self.performance.blank? then
      self.theater_id = self.performance.production.theater_id
    elsif self.contains_flex_pass?
      self.theater_id = self.flex_pass_line_items[0].flex_pass_offer.theater_id
    end
  end

end
