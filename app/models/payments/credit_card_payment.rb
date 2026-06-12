unless defined? InvalidCreditCard
  class InvalidCreditCard < StandardError
  end

  class CannotProcessPayment < StandardError
  end
end

class CreditCardPayment < CurrencyPayment
  belongs_to :address, optional: true

  attr_accessor :card_number, :card_verification_number

  validates_credit_card_if_new :card_number,
                               :card_type, {}, :confirmation_code
  validates :card_type, presence: { if: :needs_confirmation_code? }
  validates :card_last_four, presence: { if: :needs_confirmation_code? }
  validates :card_number, presence: { if: :needs_confirmation_code? }
  validates :card_expiration_year, presence: { if: :needs_confirmation_code? }
  validates :card_expiration_month, presence: { if: :needs_confirmation_code? }
  validates :confirmation_code, presence: true
  before_validation :set_defaults

  def needs_confirmation_code?
    confirmation_code.blank?
  end

  def default_from_order
    self.address ||= order.address
    self.amount ||= order.current_total
    self.ip_address ||= order.ip_address
  end

  def set_defaults
    self.card_last_four ||= card_number.nil? ? '' : card_number[-4..]
  end

  def receipt_description
    ctype = case card_type
            when 'MasterCard'
              'MC'
            when 'American Express'
              'Amex'
            when 'Discover'
              'Dscvr'
            when 'master_card'
              'MC'
            else
              card_type
            end
    "#{ctype} ****#{card_last_four}::AUTH #{confirmation_code}"
  end

  def process!(order = nil)
    if confirmation_code.blank? || card_number.length != 4
      credit_card = create_credit_card
      billing_address = {
        name: "#{address.first_name} #{address.last_name}",
        address1: address.line1,
        address2: address.line2,
        city: address.city,
        state: address.state,
        zip: address.zipcode,
        country: 'US',
        phone: address.phone
      }

      gateway = PaymentProcessing.gateway

      order ||= self.order
      options = {
        ip: ip_address,
        billing_address: billing_address,
        email: address.email,
        order_id: order_id,
        description: order.description,
        idempotency_key: order.uuid
      }
      response = gateway.purchase(charge_amount, credit_card, options)

      # Authorize for the amount
      #     response = gateway.purchase(self.charge_amount, credit_card)

      if response.success?
        self.confirmation_code = response.authorization
        self.transaction_id = response.params['transaction_id'] || confirmation_code # Returned transaction id from paypal

      end

      raise CannotProcessPayment, response.message.to_s unless response.success?

    end
    super
  end

  def refund!(_cc_number = nil, note = nil)
    return unless create_refund_payment?

    CreditCardPayment.transaction do
      gateway = PaymentProcessing.gateway

      refund_payment = dup
      refund_payment.amount = 0.0 - amount
      refund_payment.ipn_track_id = nil
      order.payments << refund_payment

      refund_amount = charge_amount

      response = gateway.refund(refund_amount, transaction_id || confirmation_code, note: note)

      unless response.success?
        # Check if charge was already refunded in Stripe
        raise CannotProcessPayment, response.message unless response.message.include?('already been refunded')

        Rails.logger.warn("Charge #{transaction_id || confirmation_code} already refunded in Stripe, reconciling order record")

        # Get the actual refunded amount from Stripe
        actual_refund_amount = get_stripe_refund_amount

        if actual_refund_amount.nil?
          # If we can't retrieve the amount from Stripe, assume it was refunded for the full amount
          # This can happen if the charge was refunded outside our system or with different API keys
          Rails.logger.warn("Could not retrieve actual refund amount from Stripe, assuming full refund of #{amount}")
          actual_refund_amount = charge_amount # Use the original charge amount
        end

        # Update refund payment to match actual Stripe refund amount
        refund_payment.amount = 0.0 - (actual_refund_amount / 100.0)
        refund_payment.save!

        # If there's a difference between what Stripe refunded and order amount,
        # create a carryover payment for the difference
        difference = amount - (actual_refund_amount / 100.0)
        if difference.abs > 0.01 # Allow for rounding errors
          carryover = PriceOverridePayment.new(
            amount: -difference,
            order: order,
            source_payment_type: payment_type
          )
          carryover.save!
          Rails.logger.info("Created carryover payment of #{-difference} for difference between order (#{amount}) and Stripe refund (#{actual_refund_amount / 100.0})")
        end

        return # Successfully reconciled

      end

      refund_payment.save!
    end
  end

  def payment_info
    "#{card_type} ending in #{card_last_four.nil? ? '????' : card_last_four.to_s}"
  end

  def create_credit_card
    address.regularize!
    PaymentProcessing.credit_card(card_type, address.first_name, address.last_name, card_number,
                                  card_expiration_month, card_expiration_year, card_verification_number)
  end

  def calculate_processing_fee
    effective_date = created_at || order&.created_at
    if effective_date && effective_date > Date.parse('16-07-2021')
      amount > 0 ? (0.30 + (amount * 0.035)).round(2) : 0
    else
      amount > 0 ? (0.22 + (amount * 0.04)).round(2) : 0
    end
  end

  def self.card_types
    @@credit_card_types ||= ActiveRecord::Validations::ClassMethods::DEFAULT_CREDIT_CARD_TYPES.values.sort - ['invalid'] + $ADDITIONAL_CARD_TYPES
  end

  protected

  def charge_amount
    (amount * 100.0).to_i
  end

  def get_stripe_refund_amount
    # Query Stripe to get the actual refund amount for this charge
    charge_id = transaction_id || confirmation_code

    begin
      Rails.logger.info("Retrieving refund info from Stripe for charge: #{charge_id}")

      # Stripe charge IDs start with 'ch_', payment intent IDs start with 'pi_'
      if charge_id.to_s.start_with?('pi_')
        # For payment intents, we need to get the charge from the payment intent
        Rails.logger.info('Charge ID is a payment intent, retrieving associated charge')
        payment_intent = Stripe::PaymentIntent.retrieve(charge_id)
        charge_id = payment_intent.charges.data.first&.id

        if charge_id.nil?
          Rails.logger.error("No charge found for payment intent #{transaction_id || confirmation_code}")
          return nil
        end
        Rails.logger.info("Found charge #{charge_id} from payment intent")
      end

      charge = Stripe::Charge.retrieve(charge_id)
      Rails.logger.info("Retrieved charge #{charge_id}: refunded=#{charge.refunded}, amount_refunded=#{charge.amount_refunded}, amount=#{charge.amount}")

      # Check if charge has been refunded
      if charge.refunded
        # Return the total amount refunded (in cents)
        Rails.logger.info("Charge has been refunded: #{charge.amount_refunded} cents")
        charge.amount_refunded
      elsif charge.amount_refunded && charge.amount_refunded > 0
        # Partially refunded
        Rails.logger.info("Charge has been partially refunded: #{charge.amount_refunded} cents")
        charge.amount_refunded
      else
        Rails.logger.error("Stripe charge #{charge_id} is not marked as refunded (refunded=#{charge.refunded}, amount_refunded=#{charge.amount_refunded})")
        Rails.logger.error("Full charge data: #{charge.to_hash.inspect}")
        nil
      end
    rescue Stripe::InvalidRequestError => e
      Rails.logger.error("Failed to retrieve Stripe charge #{charge_id}: #{e.message}")
      Rails.logger.error("Backtrace: #{e.backtrace.first(5).join("\n")}")
      nil
    rescue StandardError => e
      Rails.logger.error("Unexpected error retrieving Stripe refund amount for #{charge_id}: #{e.class.name}: #{e.message}")
      Rails.logger.error("Backtrace: #{e.backtrace.first(5).join("\n")}")
      nil
    end
  end

  private

  def get_purchase_options
    {
      order_id: id,
      ip: 'The IP address of the customer making the purchase',
      customer: 'The name, customer number, or other information that identifies the customer',
      invoice: 'The invoice number',
      merchant: 'The name or description of the merchant offering the product',
      description: 'A description of the transaction',
      email: email,
      billing_address: {
        name: full_name,
        address1: billing_address_line1,
        address2: billing_address_line2,
        city: billing_address_city,
        state: billing_address_state,
        country: 'US',
        zip: billing_address_zipcode
      },
      shipping_address: {
        name: full_name,
        address1: billing_address_line1,
        address2: billing_address_line2,
        city: billing_address_city,
        state: billing_address_state,
        country: 'US',
        zip: billing_address_zipcode
      }
    }
  end
end
