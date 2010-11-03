class Order < ActiveRecord::Base
  include PaymentFormFields
  
  belongs_to            :performance
  has_many              :payments
  has_many              :credit_card_payments
  has_many              :cash_payments
  has_many              :flex_pass_payments

  has_many                       :line_items
  has_many                       :ticket_line_items
  has_many                       :flex_pass_line_items
  has_many                       :special_offer_line_items
  belongs_to                     :address
  accepts_nested_attributes_for  :line_items, 
                                 :ticket_line_items, 
                                 :flex_pass_line_items, 
                                 :special_offer_line_items, 
                                 :address, 
                                 :payments, 
                                 :cash_payments, 
                                 :credit_card_payments, :allow_destroy => true
  attr_accessor         :special_offer_code
  attr_accessor         :door_sale
  attr_accessor_with_default :email_confirmation,0
  
  ORDER_STATUSES                                                                                    = (
  HOLD,   WEB,   NEW,   PROCESSING,   PROCESSED,   REFUNDED,   EXCHANGED,   FULFILLED,   CANCELED   =
  "Hold", "Web", "New", "Processing", "Processed", "Refunded", "Exchanged", "Fulfilled", "Canceled"   )

  PAYMENT_TYPES                                                                                     = (
  CASH,   CREDIT_CARD,   FLEX_PASS                                                                  =
  "Cash", "Credit Card", "FlexPass"                                                                   )

  validates_inclusion_of :status,           :in => ORDER_STATUSES
  validates_inclusion_of :payment_type,     :in => PAYMENT_TYPES

  validates_presence_of  :address, :status
  validates_associated   :address, 
                         :payments, :credit_card_payments, :cash_payments,
                         :line_items, :ticket_line_items, :flex_pass_line_items, :special_offer_line_items
  
  before_validation_on_create :initialize_nested_line_items
  before_validation :set_defaults
  
  validates_each :status do |record, attr, value|
    if value == PROCESSED
      unless record.total == record.value_of_all_payments || record.ticket_quantity == record.number_of_tickets_of_all_payments
        record.errors.add attr, "cannot be set to #{PROCESSED} if the total isn't countered by a payment."
      end
    end
  end
    
  def value_of_all_payments
    self.payments.to_a.sum{|p|p.amount} + 
    self.credit_card_payments.to_a.sum{|ccp|ccp.amount} + 
    self.cash_payments.to_a.sum{|cp|cp.amount} 
#    self.exchange_payments.to_a.sum{|exp|exp.amount}
  end

  def number_of_tickets_of_all_payments
    self.flex_pass_payments.to_a.sum{|fpp|fpp.number_of_tickets}
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
    self.performance.try(:performance_code)
  end

  def total(reload_line_items=false)
    (self.line_items(reload_line_items) + 
     self.ticket_line_items(reload_line_items) + 
     self.special_offer_line_items(reload_line_items) + 
     self.flex_pass_line_items(reload_line_items)
    ).uniq.to_a.sum{|line_item|line_item.respond_to?(:total) ? line_item.total : 0}
  end
  
  def total_as_currency
    number_to_currency(self.total,:delimiter => ",", :unit => "$",:separator => ".", :precision => 2)
  end
  
  def ticket_quantity 
    self.ticket_line_items(false).uniq.to_a.sum{|li| li.respond_to?(:ticket_count) ? li.ticket_count : 0}
  end
  

  def editable?
    [HOLD,NEW,nil].include? self.status
  end

  def full_name
    "#{self.first_name} #{self.last_name}"
  end
  
  def refund!
    Order.transaction do
      self.payments.each{|payment|payment.refund! if payment.respond_to? :refund! }
      self.line_items.each{|li|li.refund! if li.respond_to? :refund!}
      self.status = REFUNDED
      save!
    end
    
  end
  
  def cancel!
    Order.delete(self.id)
  end
  
  def exchange_and_process_from!( original_order )
    Order.transaction do
      self.address = original_order.address
      original_order.status = Order::EXCHANGED
      exchange_payment_on_original_order = ExchangePayment.create!(:order=>original_order, :amount=>-1*original_order.payments(true).to_a.sum{|p|p.amount}, :note=>original_order.description)
      exchange_payment_on_self = ExchangePayment.create!(:order=>self, :amount=>-1 * exchange_payment_on_original_order.amount, :payment_id=>exchange_payment_on_original_order.id)
      exchange_payment_on_original_order.update_attribute(:payment_id, exchange_payment_on_self.id)
      payment_difference = self.total - exchange_payment_on_self.amount
      PriceOverridePayment.create!(:order=>self, :amount=>payment_difference) unless payment_difference == 0
      self.status=Order::PROCESSED
      self.set_email_confirmation
      self.payments(true)
      self.save!
      original_order.release_tickets!
      original_order.save!
    end
  end
  
  def set_email_confirmation
    now = DateTime.now
    if !self.performance.nil? && (self.performance.performance_date > Date.today || (self.performance.performance_date == Date.today && self.performance.performance_time > Time.now - (60*60)))
      self.email_confirmation=1
    end
  end
  
  def update_special_offer_line_items_from_code!
    self.special_offer_line_items.clear
    special_offer = SpecialOffer.find(:first,
      :conditions => ["code = trim(lower(?)) and (performance_id = ? or production_id = ? or theater_id = ? or (performance_id is null and production_id is null and theater_id is null))",
        self.special_offer_code,
        self.performance.id,
        self.performance.production.id,
        self.performance.production.theater.id])
    if special_offer
      self.special_offer_line_items.create!(:special_offer=>special_offer)
    end
  end

  
  def description
    performance_s = self.performance.nil_or.to_short_s
    "#{performance_s} (#{self.ticket_detail_description})"
  end
  
  def ticket_detail_description
    self.ticket_line_items.map{ |li| if li.ticket_count > 0 
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
  
  
  private
  
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
    
    case self.payment_type
    when CASH
      self.cash_payments.build(:amount => self.total)
    when CREDIT_CARD
      new_payment = self.credit_card_payments.build(
        :amount => self.total, 
        :address => self.address,
        :card_number => self.credit_card_number,
        :card_expiration_month => self.credit_card_expiration_month,
        :card_expiration_year => self.credit_card_expiration_year,
        :card_type => self.credit_card_type,
        :card_verification_number => self.credit_card_verification_number,
        :confirmation_code => self.credit_card_confirmation_code
      )
      new_payment.process!
    when FLEX_PASS
      flex_pass = FlexPass.find_by_code(self.flex_pass_code)
      raise 'No FlexPass with that code exists' unless flex_pass
      new_payment = self.flex_pass_payments.build(
        :number_of_tickets => self.ticket_quantity,
        :flex_pass => flex_pass,
        :amount => flex_pass.flex_pass_offer.payout_per_ticket * self.ticket_quantity
      )
    else
      raise 'New payment type not yet implemented.'
    end
    
    self.status = Order::PROCESSED
    self.set_email_confirmation
    self.save!
  end
  
  def initialize_nested_line_items
    line_items.each { |li| li.order = self }
  end
  
  def set_defaults
    self.status ||= HOLD
    self.payment_type ||= CREDIT_CARD
    self.ticket_line_items.each{|tli|tli.order=self}
    self.flex_pass_line_items.each{|tli|tli.order=self}
  end
  
end
