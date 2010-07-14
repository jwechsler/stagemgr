class Order < ActiveRecord::Base
  belongs_to            :performance
  has_many              :payments
  has_many              :credit_card_payments
  has_many              :cash_payments

  has_many                       :line_items
  has_many                       :ticket_line_items
  #has_many                       :special_offer_line_items
  belongs_to                     :address
  accepts_nested_attributes_for  :line_items, 
                                 :ticket_line_items, 
  #                               :special_offer_line_items, 
                                 :address, 
                                 :payments, 
                                 :cash_payments, 
                                 :credit_card_payments, :allow_destroy => true
  
  ORDER_STATUSES                                                                                    = (
  HOLD,   WEB,   NEW,   PROCESSING,   PROCESSED,   REFUNDED,   EXCHANGED,   FULFILLED,   CANCELED   =
  "Hold", "Web", "New", "Processing", "Processed", "Refunded", "Exchanged", "Fulfilled", "Canceled"   )

  PAYMENT_TYPES                                                                                     = (
  CREDIT_CARD,   CASH,   FLEX_PASS                                                                  =
  "Credit Card", "Cash", "FlexPass"                                                                   )

  validates_inclusion_of :status,        :in => ORDER_STATUSES
  validates_inclusion_of :payment_type,  :in => PAYMENT_TYPES

  validates_presence_of  :address, :status, :performance
  before_validation_on_create :initialize_nested_line_items
  before_validation :set_defaults
  
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

  def total
    #(self.line_items + self.ticket_line_items + self.special_offer_line_items).uniq.to_a.sum{|line_item|line_item.total}
    (self.line_items + self.ticket_line_items).uniq.to_a.sum{|line_item|line_item.total}
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

  private
  
  def initialize_nested_line_items
    line_items.each { |li| li.order = self }
  end

  def set_defaults
    self.status ||= HOLD
    self.payment_type ||= CREDIT_CARD
  end

end
