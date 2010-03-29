class Order < ActiveRecord::Base
  attr_accessor :card_number
  
  HELD,PROCESSING,PROCESSED,REFUNDED,CANCELED = 'Held', 'Processing', 'Processed', 'Refunded', 'Canceled'
  ORDER_STATUSES = [HELD,PROCESSING,PROCESSED,REFUNDED,CANCELED]
  has_many :line_items

  validates_inclusion_of   :status,            :in => ORDER_STATUSES
  validates_credit_card  :card_number, 
                         :card_type, :if=>Proc.new { |order| order.status == PROCESSING }
  validates_presence_of  :first_name,
                         :last_name,
                         :email,
                         :billing_address_city,
                         :billing_address_line1,
                         :billing_address_state,
                         :billing_address_zipcode,
                         :card_last_four,
                         :card_number,
                         :card_type, :if=>Proc.new { |order| order.status == PROCESSING }
  validates_presence_of :confirmation_code, :if=>Proc.new { |order| order.status == PROCESSED }
  validates_presence_of :status
  accepts_nested_attributes_for  :line_items, :allow_destroy => true
  before_validation_on_create :initialize_nested_line_items
  validates_each :status do |record, attr, value|
    if value == PROCESSING
      new_confirmation_code = 2345
      if new_confirmation_code
        record.confirmation_code = new_confirmation_code
        record.status = PROCESSED
      else
        record.errors.add_to_base 'Credit Card Processing Failed'
        record.status = HELD
      end
    end
  end
  
  before_validation :set_defaults
  
  private

  def initialize_nested_line_items
    line_items.each { |li| li.order = self }
  end
  
  def set_defaults
    self.status ||= HELD
    self.card_last_four = self.card_number[-4..-1] if self.card_number
  end
  
end
