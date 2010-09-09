InvalidCreditCard     = Class.new(StandardError)
CannotProcessPayment  = Class.new(StandardError)

class CreditCardPayment < Payment
  belongs_to             :address

  validates_credit_card  :card_number,
                         :card_type, {}
  validates_presence_of  :card_type,
                         :card_last_four,
                         :card_number,
                         :card_expiration_year,
                         :card_expiration_month,
                         :confirmation_code
  before_validation      :set_defaults
                         
  def default_from_order
    self.address        ||= self.order.address
    self.amount         ||= self.order.total
  end
  
  def set_defaults
    self.card_last_four ||= self.card_number.nil? ? "" : self.card_number[-4..-1]
  end

  def process!
    credit_card = ActiveMerchant::Billing::CreditCard.new(
                      :first_name         => self.address.first_name,
                      :last_name          => self.address.last_name,
                      :number             => self.card_number,
                      :month              => self.card_expiration_month,
                      :year               => self.card_expiration_year,
                      :verification_value => self.card_verification_number
                    )
    raise InvalidCreditCard, credit_card.errors.full_messages unless credit_card.valid?

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
    
    self.save!
  end
  
  def refund!
    raise 'UnimplementedException'
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

