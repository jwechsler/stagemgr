class Order < ActiveRecord::Base
  attr_accessor :card_number
  
  ORDER_STATUSES = ['Held', 'Processing', 'Processed', 'Refunded', 'Canceled']
  has_many :line_items

  validates_inclusion_of   :status,            :in => ORDER_STATUSES
  validates_credit_card :card_number, :card_type, :if=>Proc.new { |order| order.status == 'Processing' }
  validates_presence_of  :first_name,
                         :last_name,
                         :email,
                         :billing_address_city,
                         :billing_address_line1,
                         :billing_address_state,
                         :billing_address_zipcode,
                         :card_last_four,
                         :card_number,
                         :card_type, :if=>Proc.new { |order| order.status == 'Processing' }
  validates_presence_of :status
  accepts_nested_attributes_for  :line_items, :allow_destroy => true
  before_validation_on_create :initialize_nested_line_items
  
  before_validation :set_defaults
  
  private

  def initialize_nested_line_items
    line_items.each { |li| li.order = self }
  end
  
  def set_defaults
    self.status ||= ORDER_STATUSES.first
    self.card_last_four = self.card_number[-4..-1] if self.card_number
  end
  
end
