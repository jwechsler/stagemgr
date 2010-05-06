class Order < ActiveRecord::Base
  attr_accessor :card_number
  attr_accessor :card_verification_number
  belongs_to :performance
  
  HOLD,WEB,NEW,PROCESSING,PROCESSED,REFUNDED,EXCHANGED,FULFILLED,CANCELED = ["Hold", "Web", "New", "Processing", "Processed", "Refunded", "Exchanged", "Fulfilled", "Canceled"]
  ORDER_STATUSES = [HOLD,WEB,NEW,PROCESSING,PROCESSED,REFUNDED,EXCHANGED,FULFILLED,CANCELED]
  has_many :line_items

  validates_inclusion_of   :status,            :in => ORDER_STATUSES
  validates_credit_card  :card_number, 
                         :card_type, :if=>Proc.new { |order| order.status == PROCESSING }
  validates_presence_of  :first_name,
                         :last_name,
                         :billing_address_city,
                         :billing_address_line1,
                         :billing_address_state,
                         :billing_address_zipcode,
                         :card_last_four,
                         :card_number,
                         :card_expiration_year,
                         :card_expiration_month,
                         :card_type, :if=>Proc.new { |order| order.status == PROCESSING }
  validates_presence_of :confirmation_code, :if=>:should_have_confirmation_code?  # Proc.new { |order| order.status == PROCESSED }
  validates_presence_of :status, :performance
  accepts_nested_attributes_for  :line_items, :allow_destroy => true
  after_save :process_online, :if=>:should_process?
  before_validation_on_create :initialize_nested_line_items

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
    [HOLD,NEW,nil].include? self.status
  end
  
  private

  def initialize_nested_line_items
    line_items.each { |li| li.order = self }
  end
  
  def set_defaults
    self.status ||= HOLD
    self.card_last_four = self.card_number[-4..-1] if self.card_number
  end
  
  def should_have_confirmation_code?
    self.status == PROCESSED && self.card_type != 'Cash'
  end
  
  def should_process?
    self.status == PROCESSING
  end
  
  def process_online
    error_msg=nil
    credit_card = ActiveMerchant::Billing::CreditCard.new(
                      :first_name         => self.first_name,
                      :last_name          => self.last_name,
                      :number             => self.card_number,
                      :month              => self.card_expiration_month,
                      :year               => self.card_expiration_year,
                      :verification_value => self.card_verification_number
                    )
    if credit_card.valid?
      # Create a gateway object for the TrustCommerce service
      gateway = ActiveMerchant::Billing::AuthorizeNetGateway.new(
                         :login=>ACTIVE_MERCHANT_LOGIN, 
                         :password=>ACTIVE_MERCHANT_PASSWORD,
                         :test=>ACTIVE_MERCHANT_TEST_MODE)

      # Authorize for the amount
      response = gateway.purchase((self.total*100).to_i, credit_card)

      if response.success?
        puts "Successfully charged $#{sprintf("%.2f", self.total)} to the credit card ending #{self.card_last_four}"
      else
        error_msg = response.message
      end
    else
      error_msg = 'Credit card is not valid.'
    end
    if error_msg
      self.status = HOLD
      self.save!
      self.errors.add_to_base error_msg
    else
      self.confirmation_code = response.authorization
      self.status = PROCESSED
      self.save!
    end
  end
end
