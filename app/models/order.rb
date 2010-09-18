class Order < ActiveRecord::Base
  include PaymentFormFields
  
  belongs_to            :performance
  has_many              :payments
  has_many              :credit_card_payments
  has_many              :cash_payments

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
    if value == PROCESSED && record.total != record.value_of_all_payments
      record.errors.add attr, "cannot be set to #{PROCESSED} if the total isn't countered by a payment."
    end
  end
  
  def value_of_all_payments
    self.payments.to_a.sum{|p|p.amount} + 
    self.credit_card_payments.to_a.sum{|ccp|ccp.amount} + 
    self.cash_payments.to_a.sum{|cp|cp.amount} 
#    self.exchange_payments.to_a.sum{|exp|exp.amount}
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
      exchange_payment_on_original_order = ExchangePayment.create!(:order=>original_order, :amount=>-1*original_order.payments(true).to_a.sum{|p|p.amount})
      exchange_payment_on_self = ExchangePayment.create!(:order=>self, :amount=>-1 * exchange_payment_on_original_order.amount, :payment_id=>exchange_payment_on_original_order.id)
      exchange_payment_on_original_order.update_attribute(:payment_id, exchange_payment_on_self.id)
      payment_difference = self.total - exchange_payment_on_self.amount
      PriceOverridePayment.create!(:order=>self, :amount=>payment_difference) unless payment_difference == 0
      self.status=Order::PROCESSED
      self.payments(true)
      self.save!
      original_order.save!
    end
  end
  
  def process!
    payment = nil
    
    Order.transaction do
      self.status = PROCESSING
      
      case self.payment_type
      when Order::CREDIT_CARD
        payment = self.credit_card_payments.first
        if payment
          payment.default_from_order
          payment.process! unless (!payment.confirmation_code.blank? && !payment.card_number.nil? && payment.card_number.length <= 4)
          payment.save!
        else
          raise 'Trying to process a credit card order without a credit card'
        end
      when Order::CASH
        payment = self.cash_payments.create! :amount=>self.total, :note=>self.description

      when Order::FLEX_PASS
        raise 'Unimplemented'
      else
        raise 'Unimplemented'
      end
      self.status = Order::PROCESSED
      self.save!
      self.flex_pass_line_items.each do |fpli|
        fpli.flex_pass = FlexPass.create! :flex_pass_offer => fpli.flex_pass_offer, :order => self, :address => self.address
        fpli.save!
      end
    end
    
    payment
  end
  
  def update_special_offer_line_items_from_code!
    self.special_offer_line_items.clear
    special_offer = SpecialOffer.find_by_code(self.special_offer_code)
    if special_offer
      self.special_offer_line_items.create!(:special_offer=>special_offer)
    end
  end

  
  def description
    performance_s = self.performance.nil_or.to_short_s
    line_items_s = self.ticket_line_items.map{ |li| li.to_s }.join(', ')
    "#{performance_s} (#{line_items_s})"
  end
  
  def transition_to!(new_status)
    self.send "transition_#{self.status.underscore}_to_#{new_status.underscore}!".to_sym
    raise "Transition from #{self.status} to #{new_status} unsuccessful" unless self.status == new_status
  end
  
  def status_display
    case self.status
      when HOLD
        "Held"
      else
        self.status
    end
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
        :card_verification_number => self.credit_card_verification_number
      )
      new_payment.process!
    else
      raise 'New payment type not yet implemented.'
    end
    
    self.status = Order::PROCESSED
    self.save!
  end
  
  def initialize_nested_line_items
    line_items.each { |li| li.order = self }
  end

  def set_defaults
    self.status ||= HOLD
    self.payment_type ||= CREDIT_CARD
    self.ticket_line_items.each{|tli|tli.order=self}
  end
  
end
