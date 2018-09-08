if !defined? InvalidCreditCard
  InvalidCreditCard = Class.new(StandardError)
  CannotProcessPayment = Class.new(StandardError)
end

class CreditCardPayment < CurrencyPayment


  belongs_to :address

  attr_accessor :card_number
  attr_accessor :card_verification_number


  validates_credit_card_if_new :card_number,
                               :card_type, {}, :confirmation_code
  validates_presence_of :card_type, :if => :needs_confirmation_code?
  validates_presence_of :card_last_four, :if => :needs_confirmation_code?
  validates_presence_of :card_number, :if => :needs_confirmation_code?
  validates_presence_of :card_expiration_year, :if => :needs_confirmation_code?
  validates_presence_of :card_expiration_month, :if => :needs_confirmation_code?
  validates_presence_of :confirmation_code
  before_validation :set_defaults

  def needs_confirmation_code?
    self.confirmation_code.blank?
  end

  def default_from_order
    self.address ||= self.order.address
    self.amount ||= self.order.total
    self.ip_address ||= self.order.ip_address
  end

  def set_defaults
    self.card_last_four ||= self.card_number.nil? ? "" : self.card_number[-4..-1]
  end

  def receipt_description
    ctype = case self.card_type
              when 'MasterCard'
                'MC'
              when 'American Express'
                'Amex'
              when 'Discover'
                'Dscvr'
              when 'master_card'
                'MC'
              else
                self.card_type
            end
    "#{ctype} ****#{self.card_last_four}::AUTH #{confirmation_code}"
  end

  def process!(order = nil)
    if self.confirmation_code.blank? || self.card_number.length != 4
      credit_card = create_credit_card
      billing_address = {
        :name => "#{self.address.first_name} #{self.address.last_name}",
        :address1 => self.address.line1,
        :address2 => self.address.line2,
        :city => self.address.city,
        :state => self.address.state,
        :zip => self.address.zipcode,
        :country => 'US',
        :phone => self.address.phone
      }

      # Create paypal gateway

      gateway = PaymentProcessing.gateway


      response = gateway.purchase(self.charge_amount, credit_card, :ip=>self.ip_address, :billing_address=>billing_address, :email => self.address.email, :order_id => self.order_id, :description => self.order.description)

# Authorize for the amount
#     response = gateway.purchase(self.charge_amount, credit_card)

      if response.success?
        self.confirmation_code = response.authorization
        self.transaction_id = response.params["transaction_id"] # Returned transaction id from paypal
      end

      unless response.success?
        raise CannotProcessPayment, "#{response.message}"
      end

    end
    super
  end

  def refund!(cc_number = nil, note = nil)


    CreditCardPayment.transaction do

      gateway = PaymentProcessing.gateway

      refund_payment = self.dup
      refund_payment.amount = self.amount*-1
      refund_payment.ipn_track_id = nil
      self.order.payments << refund_payment

      refund_amount = (self.amount*100).to_i


      response = gateway.credit(refund_amount, self.transaction_id, :note => note)

      unless response.success?
        raise CannotProcessPayment, response.message
      end

      refund_payment.save!

    end
  end

  def payment_info
    "#{self.card_type} ending in #{self.card_last_four.nil? ? "????" : self.card_last_four.to_s}"
  end

  def create_credit_card
    PaymentProcessing.credit_card(self.card_type, self.address.first_name, self.address.last_name, self.card_number,
     self.card_expiration_month, self.card_expiration_year, self.card_verification_number)
  end

  def processing_fee
    0.22 + self.amount * 0.04
  end

  def self.card_types
    @@credit_card_types ||= ActiveRecord::Validations::ClassMethods::DEFAULT_CREDIT_CARD_TYPES.values.sort - ['invalid'] + $ADDITIONAL_CARD_TYPES
  end

  protected
  def charge_amount
    (self.amount*100).to_i
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

