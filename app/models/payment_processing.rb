require "active_merchant/billing/rails"
require 'json'
module PaymentProcessing

  class BogusResponse < ActiveMerchant::Billing::Response

    PROFILE_ID = 'TEST_PROFILE_ID'

  end
  
  class BogusGateway < ActiveMerchant::Billing::BogusGateway
    class_attribute :profiles
    attr_accessor :price_id

    def recurring(money, credit_card, options={})
      response = purchase(money, credit_card, options)
      profile_id = "#{BogusResponse::PROFILE_ID}#{Time.now.strftime('%Y%m%d%H%H%S')}"
      # response = BogusResponse.new(true, "", options)
      response.params['profile_id'] = profile_id
      response.params['profile_status'] = 'ActiveProfile'
      BogusGateway.profiles = Hash.new if BogusGateway.profiles.nil?
      if BogusGateway.profiles[profile_id].nil?
        balance = money
        BogusGateway.profiles[profile_id] = response.params.merge({
          'outstanding_balance'=>balance,
          'aggregate_amount'=>0,
          'number_cycles_completed'=>0,
          'final_payment_due_date'=>(options[:start_date].to_date + options[:total_billing_cycles].to_i.months)
        }).merge(options)
      end
      response
    end

    def status_recurring(profile_id)

      r = BogusResponse.new(true, "Forced Response")
      r.params['profile_id'] = profile_id
      r.params['profile_status'] = 'ActiveProfile'
      BogusGateway.profiles ||= Hash.new
      if BogusGateway.profiles[profile_id].nil? then
        BogusGateway.profiles[profile_id]={'balance': 9900, 'outstanding_balance': 9900, 'aggregate_amount':0,
          'number_cycles_completed':0, 'final_payment_due_date': Date.today + 1.year }
      end
      r.params.merge!(BogusGateway.profiles[profile_id])
      r
    end

    def product_url(price_id)
      self.price_id = price_id
    end

    def create_subscription(order)
      return 'TESTSUBSCRIPTION'
    end

    def subscription_url(subscription_id)
      return Rails.root + "TESTSUBSCRIPTION"
    end

    def external_type(transaction_id)
      return "test"
    end

    def external_url(transaction_id)
      return "http://localhost"
    end
  end

  def self.after_initialize
    if $PAYMENT_CONFIG['default_gateway'].eql?('paypal') || $PAYMENT_CONFIG['default_recurring_gateway'].eql?('paypal') then
      unless ENV['PAYPAL_PEM_FILE'].nil?
        pem_file = File.read(::Rails.root.to_s+"/config/#{ENV['PAYPAL_PEM_FILE']}")
        ActiveMerchant::Billing::PaypalGateway.pem_file = pem_file
      end
    end
    if $PAYMENT_CONFIG['default_gateway'].eql?('stripe') || $PAYMENT_CONFIG['default_recurring_gateway'].eql?('stripe') then
      Stripe.api_key = ENV['STRIPE_SECRET_KEY']
    end
  end

  def self.recurring_gateway(requested_gateway = nil)
    requested_gateway ||= default_recurring_gateway
    gateway(requested_gateway)
  end

  def self.gateway(requested_gateway = nil)
    requested_gateway ||= default_gateway
    case requested_gateway
    when 'paypal'
      if ENV['PAYPAL_SIGNATURE'].nil? then
        ActiveMerchant::Billing::PaypalGateway.new(:login => ENV['PAYPAL_LOGIN'],
          :password => ENV['PAYPAL_PASSWORD'])
      else
        ActiveMerchant::Billing::PaypalGateway.new(:login => ENV['PAYPAL_LOGIN'],
          :password => ENV['PAYPAL_PASSWORD'],
          :signature => ENV['PAYPAL_SIGNATURE'])
      end
    when 'paypal_express'
      ActiveMerchant::Billing::PaypalExpressGateway.new(:login => ENV['PAYPAL_EXPRESS_LOGIN'],
        :password => ENV['PAYPAL_PASSWORD'])
    when 'stripe'
      Stripe.api_key = ENV['STRIPE_SECRET_KEY']
      StripeGateway.new(:login=>Stripe.api_key)
      
    when 'bogus'
        PaymentProcessing::BogusGateway.new
    end
  end

  def self.create_subscription(order)
    gateway.create_subscription(order)
  end

  def self.credit_card(card_type, first_name, last_name, card_number, card_expiration_month, card_expiration_year, verification_number)
    Rails.logger.debug("Using test credit card number of #{$PAYMENT_CONFIG['test_credit_card']}") if $PAYMENT_CONFIG.has_key?('test_credit_card') 
    credit_card = ActiveMerchant::Billing::CreditCard.new(
      :brand => credit_card_type(card_type),
      :first_name => first_name,
      :last_name => last_name,
      :number => $PAYMENT_CONFIG.has_key?('test_credit_card') ? $PAYMENT_CONFIG['test_credit_card'].to_s : card_number,
      :month => card_expiration_month,
      :year => card_expiration_year,
      :verification_value => verification_number
    )
    raise InvalidCreditCard, credit_card.errors.map{|field, message| "#{field} #{message}"}.join(", ") unless credit_card.valid?
    credit_card
  end

  private

  def self.default_recurring_gateway
    $PAYMENT_CONFIG['default_recurring_gateway']
  end

  def self.default_gateway
    $PAYMENT_CONFIG['default_gateway']
  end

  def self.subscription_url(subscription_id)
    gateway.subscription_url(subscription_id)
  end

  def self.product_url(price_id)
    gateway.product_url(price_id)
  end

  def self.credit_card_type(ctype)
    return $PAYMENT_CONFIG['test_card_brand'] if $PAYMENT_CONFIG.has_key?('test_card_brand')

    case ctype
      when 'MasterCard'
        "master"
      when 'master_card'
        "master"
      when 'American Express'
        "american_express"
      else
        ctype
    end
  end

  def self.external_url(transaction_id)
    gateway.external_url(transaction_id)
  end

  def self.external_type(transaction_id)
    gateway.external_type(transaction_id)
  end
end


