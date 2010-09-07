class Order < ActiveRecord::Base
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
  CREDIT_CARD,   CASH,   FLEX_PASS                                                                  =
  "Credit Card", "Cash", "FlexPass"                                                                   )

  validates_inclusion_of :status,        :in => ORDER_STATUSES
  validates_inclusion_of :payment_type,  :in => PAYMENT_TYPES

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
    ).uniq.to_a.sum{|line_item|line_item.total}
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
  
  def exchange_and_process_from!( original_order )
    self.address = original_order.address
    original_order.status = Order::EXCHANGED
    exchange_payment_on_original_order = ExchangePayment.create!(:order=>original_order, :amount=>-1*original_order.payments(true).to_a.sum{|p|p.amount})
    exchange_payment_on_self = ExchangePayment.create!(:order=>self, :amount=>-1 * exchange_payment_on_original_order.amount)
    payment_difference = self.total - exchange_payment_on_self.amount
    PriceOverridePayment.create!(:order=>self, :amount=>payment_difference) unless payment_difference == 0
    self.status=Order::PROCESSED
    self.payments(true)
    self.save!
    original_order.save!
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
          payment.process!
          payment.save!
        else
          raise 'Trying to process a credit card order without a credit card'
        end
      when Order::CASH
        payment = self.cash_payments.create! :amount=>self.total
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
    d = self.performance.to_short_s + " ("
    c = false;
    line_items.each { |li| 
      d += li.to_s 
      if c then
        d += ", "
      else
        c = true
      end
    }
    d += ")"
    "#{d}"
  end

  private
  
  def initialize_nested_line_items
    line_items.each { |li| li.order = self }
  end

  def set_defaults
    self.status ||= HOLD
    self.payment_type ||= CREDIT_CARD
    self.ticket_line_items.each{|tli|tli.order=self}
  end
  
end
