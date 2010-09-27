InvalidCreditCard     = Class.new(StandardError)
CannotProcessPayment  = Class.new(StandardError)

class CreditCardPayment < Payment
  belongs_to             :address

  attr_accessor :card_number
  attr_accessor :card_verification_number

  validates_credit_card_if_new  :card_number,
                         :card_type, {}, :confirmation_code     
  validates_presence_of  :card_type, :if => :needs_confirmation_code?
  validates_presence_of  :card_last_four, :if => :needs_confirmation_code?
  validates_presence_of  :card_number, :if => :needs_confirmation_code? 
  validates_presence_of  :card_expiration_year, :if => :needs_confirmation_code?
  validates_presence_of  :card_expiration_month, :if => :needs_confirmation_code?
  validates_presence_of  :confirmation_code
  before_validation      :set_defaults
  
  def needs_confirmation_code?
    self.confirmation_code.blank?
  end 
                         
  def default_from_order
    self.address        ||= self.order.address
    self.amount         ||= self.order.total
  end
  
  def set_defaults
    self.card_last_four ||= self.card_number.nil? ? "" : self.card_number[-4..-1]
  end

  def process!
    if self.confirmation_code.blank? || self.card_number.length != 4
      ctype = case self.card_type
      when 'MasterCard'
        "master"
      when 'master_card'
        "master"
      when 'American Express'
        "american_express"
      else
        self.card_type
      end
      raise InvalidCreditCard, "type is #{ctype}"
      
      credit_card = ActiveMerchant::Billing::CreditCard.new(
                        :type               => ctype,
                        :first_name         => self.address.first_name,
                        :last_name          => self.address.last_name,
                        :number             => self.card_number,
                        :month              => self.card_expiration_month,
                        :year               => self.card_expiration_year,
                        :verification_value => self.card_verification_number
                      )
      raise InvalidCreditCard, credit_card.errors.full_messages.join("\n") unless credit_card.valid?

      # Create a gateway object for the TrustCommerce service
      gateway_options = {
        :login=>ACTIVE_MERCHANT_LOGIN,
        :password=>ACTIVE_MERCHANT_PASSWORD,
        :test=>ACTIVE_MERCHANT_TEST_MODE}
      # Create a gateway object for the TrustCommerce service
      gateway = ActiveMerchant::Billing::AuthorizeNetGateway.new(
        gateway_options
      )

      # Authorize for the amount
      response = gateway.purchase((self.amount*100).to_i, credit_card)

      unless response.success?
        raise CannotProcessPayment, response.message 
      end
        
      self.confirmation_code = response.authorization
    end
    self.save!
  end
  
  def refund!
    raise 'UnimplementedException'
  #  I think all the below is gibberish now and needs to be refactored for the new payment model? --jw
    CreditCardPayment.transaction do
      refund_payment = self.order.credit_card_payments.build(
                                                    :amount                   => self.amount*-1,
                                                    :payment_id               => self.id,
                                                    :card_type                => self.card_type,
                                                    :card_number              => self.card_number,
                                                    :card_expiration_month    => self.card_expiration_month,
                                                    :card_expiration_year     => self.card_expiration_year,
                                                    :card_verification_number => self.card_verification_number,
                                                    :address                  => self.address
                                                  )
      refund_payment.process!
      self.payment_id=refund_payment.id
      self.save!
    end
  end
  
  private
  
  def get_purchase_options
    purchase_options = {
      :order_id => self.id,
      :ip => 'The IP address of the customer making the purchase',
      :customer => 'The name, customer number, or other information that identifies the customer',
      :invoice => 'The invoice number',
      :merchant => 'The name or description of the merchant offering the product',
      :description => 'A description of the transaction',
      :email => self.email,
      :billing_address =>
      {
        :name => self.full_name,
        :address1 => self.billing_address_line1,
        :address2 => self.billing_address_line2,
        :city => self.billing_address_city,
        :state => self.billing_address_state,
        :country => 'US',
        :zip => self.billing_address_zipcode
      },
      :shipping_address =>
      {
        :name => self.full_name,
        :address1 => self.billing_address_line1,
        :address2 => self.billing_address_line2,
        :city => self.billing_address_city,
        :state => self.billing_address_state,
        :country => 'US',
        :zip => self.billing_address_zipcode
      }
    }
  end

end

