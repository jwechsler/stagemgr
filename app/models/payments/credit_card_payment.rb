if !defined? InvalidCreditCard
  InvalidCreditCard = Class.new(StandardError)
  CannotProcessPayment = Class.new(StandardError)
end

class CreditCardPayment < CurrencyPayment


  belongs_to :address, optional: true

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
    self.amount ||= self.order.current_total
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

      gateway = PaymentProcessing.gateway

      order = order || self.order
      options = {
        ip: self.ip_address, 
        billing_address: billing_address, 
        email: self.address.email, 
        order_id: order_id, 
        description: order.description,
        idempotency_key: order.uuid
      }
      response = gateway.purchase(self.charge_amount, credit_card, options)

# Authorize for the amount
#     response = gateway.purchase(self.charge_amount, credit_card)

      if response.success?
        self.confirmation_code = response.authorization
        self.transaction_id = response.params["transaction_id"] || self.confirmation_code # Returned transaction id from paypal

      end

      unless response.success?
        raise CannotProcessPayment, "#{response.message}"
      end

    end
    super
  end

  def refund!(cc_number = nil, note = nil)
    if self.create_refund_payment?
      CreditCardPayment.transaction do

        gateway = PaymentProcessing.gateway

        refund_payment = self.dup
        refund_payment.amount = 0.0-self.amount
        refund_payment.ipn_track_id = nil
        self.order.payments << refund_payment

        refund_amount = self.charge_amount

        response = gateway.refund(refund_amount, self.transaction_id || self.confirmation_code, :note => note)

        unless response.success?
          # Check if charge was already refunded in Stripe
          if response.message.include?("already been refunded")
            Rails.logger.warn("Charge #{self.transaction_id || self.confirmation_code} already refunded in Stripe, reconciling order record")

            # Get the actual refunded amount from Stripe
            actual_refund_amount = get_stripe_refund_amount

            if actual_refund_amount.nil?
              raise CannotProcessPayment, "Could not retrieve refund amount from Stripe: #{response.message}"
            end

            # Update refund payment to match actual Stripe refund amount
            refund_payment.amount = 0.0 - (actual_refund_amount / 100.0)
            refund_payment.save!

            # If there's a difference between what Stripe refunded and order amount,
            # create a carryover payment for the difference
            difference = self.amount - (actual_refund_amount / 100.0)
            if difference.abs > 0.01 # Allow for rounding errors
              carryover = PriceOverridePayment.new(
                amount: -difference,
                order: self.order,
                source_payment_type: self.payment_type
              )
              carryover.save!
              Rails.logger.info("Created carryover payment of #{-difference} for difference between order (#{self.amount}) and Stripe refund (#{actual_refund_amount / 100.0})")
            end

            return # Successfully reconciled
          else
            raise CannotProcessPayment, response.message
          end
        end

        refund_payment.save!
      end
    end
  end

  def payment_info
    "#{self.card_type} ending in #{self.card_last_four.nil? ? "????" : self.card_last_four.to_s}"
  end

  def create_credit_card
    self.address.regularize!
    PaymentProcessing.credit_card(self.card_type, self.address.first_name, self.address.last_name, self.card_number,
     self.card_expiration_month, self.card_expiration_year, self.card_verification_number)
  end

  def processing_fee
    if self.created_at > Date.parse("16-07-2021")
      (self.amount) > 0 ? (0.30 + self.amount * 0.035).round(2) : 0
    else
      (self.amount) > 0 ? (0.22 + self.amount * 0.04).round(2) : 0
    end
  end

  def self.card_types
    @@credit_card_types ||= ActiveRecord::Validations::ClassMethods::DEFAULT_CREDIT_CARD_TYPES.values.sort - ['invalid'] + $ADDITIONAL_CARD_TYPES
  end

  protected
  def charge_amount
    (self.amount*100.0).to_i
  end

  def get_stripe_refund_amount
    # Query Stripe to get the actual refund amount for this charge
    begin
      charge_id = self.transaction_id || self.confirmation_code

      # Stripe charge IDs start with 'ch_', payment intent IDs start with 'pi_'
      if charge_id.start_with?('pi_')
        # For payment intents, we need to get the charge from the payment intent
        payment_intent = Stripe::PaymentIntent.retrieve(charge_id)
        charge_id = payment_intent.charges.data.first&.id
        return nil if charge_id.nil?
      end

      charge = Stripe::Charge.retrieve(charge_id)

      # Check if charge has been refunded
      if charge.refunded
        # Return the total amount refunded (in cents)
        return charge.amount_refunded
      else
        Rails.logger.warn("Stripe charge #{charge_id} is not marked as refunded")
        return nil
      end
    rescue Stripe::InvalidRequestError => e
      Rails.logger.error("Failed to retrieve Stripe charge #{charge_id}: #{e.message}")
      return nil
    rescue => e
      Rails.logger.error("Unexpected error retrieving Stripe refund amount: #{e.message}")
      return nil
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

