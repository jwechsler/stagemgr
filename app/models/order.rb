class Order < ActiveRecord::Base
  attr_accessor :card_number
  attr_accessor :card_verification_number
  belongs_to :performance
  
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
                         :card_expiration_year,
                         :card_expiration_month,
                         :card_type, :if=>Proc.new { |order| order.status == PROCESSING }
  validates_presence_of :confirmation_code, :if=>Proc.new { |order| order.status == PROCESSED }
  validates_presence_of :status, :performance
  accepts_nested_attributes_for  :line_items, :allow_destroy => true
  before_validation_on_create :initialize_nested_line_items
  validates_each :status do |record, attr, value|
    if value == PROCESSING
      error_msg=nil
      credit_card = ActiveMerchant::Billing::CreditCard.new(
                        :first_name         => record.first_name,
                        :last_name          => record.last_name,
                        :number             => record.card_number,
                        :month              => record.card_expiration_month,
                        :year               => record.card_expiration_year,
                        :verification_value => record.card_verification_number
                      )
      if credit_card.valid?
        # Create a gateway object for the TrustCommerce service
        gateway = ActiveMerchant::Billing::AuthorizeNetGateway.new(
                           :login=>ACTIVE_MERCHANT_LOGIN, 
                           :password=>ACTIVE_MERCHANT_PASSWORD,
                           :test=>ACTIVE_MERCHANT_TEST_MODE)

        # Authorize for the amount
        response = gateway.purchase((record.total*100).to_i, credit_card)

        if response.success?
          puts "Successfully charged $#{sprintf("%.2f", record.total)} to the credit card ending #{record.card_last_four}"
        else
          error_msg = response.message
        end
      else
        error_msg = 'Credit card is not valid.'
      end
      if error_msg
        record.errors.add_to_base error_msg
        record.status = HELD
      else
        record.confirmation_code = response.authorization
        record.status = PROCESSED
      end
    end
  end
  
  before_validation :set_defaults
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
    self.line_items.to_a.sum{|line_item|line_item.total}
  end
  
  def editable?
    self.status == HELD || self.status.nil?
  end
  
  private

  def initialize_nested_line_items
    line_items.each { |li| li.order = self }
  end
  
  def set_defaults
    self.status ||= HELD
    self.card_last_four = self.card_number[-4..-1] if self.card_number
  end
  
end
