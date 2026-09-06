require 'active_merchant/billing/rails'
require 'json'
module PaymentProcessing
  class BogusResponse < ActiveMerchant::Billing::Response
    PROFILE_ID = 'TEST_PROFILE_ID'
  end

  class BogusGateway < ActiveMerchant::Billing::BogusGateway
    class_attribute :profiles
    attr_accessor :price_id

    def recurring(money, credit_card, options = {})
      response = purchase(money, credit_card, options)
      profile_id = "#{BogusResponse::PROFILE_ID}#{Time.now.strftime('%Y%m%d%H%H%S')}"
      # response = BogusResponse.new(true, "", options)
      response.params['profile_id'] = profile_id
      response.params['profile_status'] = 'ActiveProfile'
      BogusGateway.profiles = ({}) if BogusGateway.profiles.nil?
      if BogusGateway.profiles[profile_id].nil?
        balance = money
        BogusGateway.profiles[profile_id] = response.params.merge({
                                                                    'outstanding_balance' => balance,
                                                                    'aggregate_amount' => 0,
                                                                    'number_cycles_completed' => 0,
                                                                    'final_payment_due_date' => (options[:start_date].to_date + options[:total_billing_cycles].to_i.months)
                                                                  }).merge(options)
      end
      response
    end

    def status_recurring(profile_id)
      r = BogusResponse.new(true, 'Forced Response')
      r.params['profile_id'] = profile_id
      r.params['profile_status'] = 'ActiveProfile'
      BogusGateway.profiles ||= {}
      if BogusGateway.profiles[profile_id].nil?
        BogusGateway.profiles[profile_id] = { balance: 9900, outstanding_balance: 9900, aggregate_amount: 0,
                                              number_cycles_completed: 0, final_payment_due_date: Date.today + 1.year }
      end
      r.params.merge!(BogusGateway.profiles[profile_id])
      r
    end

    def product_url(price_id)
      self.price_id = price_id
    end

    def create_subscription(_order)
      'TESTSUBSCRIPTION'
    end

    def subscription_url(_subscription_id)
      # Must be a String: callers pass this to link_to, and a Pathname
      # (the old Rails.root + '...' form) crashes url_for with to_model.
      'http://localhost/TESTSUBSCRIPTION'
    end

    def external_type(_transaction_id)
      'test'
    end

    def external_url(_transaction_id)
      'http://localhost'
    end
  end

  def self.after_initialize
    # NOTE: the paypal branch read `Rails.credentials`, which does not exist in
    # Rails 6.1 (it is Rails.application.credentials) -- so any paypal
    # deployment raised NoMethodError here at boot. Routing through AppSecrets
    # fixes that; Stripe deployments were never affected.
    if gateway_configured?('paypal') && (pem_name = AppSecrets[:paypal_pem_file])
      ActiveMerchant::Billing::PaypalGateway.pem_file = read_pem_file(pem_name)
    end
    Stripe.api_key = AppSecrets[:stripe_secret_key] if gateway_configured?('stripe')
  end

  # True when either the one-off or the recurring gateway is the named one.
  def self.gateway_configured?(name)
    default_gateway.eql?(name) || default_recurring_gateway.eql?(name)
  end

  # An absolute PAYPAL_PEM_FILE is used as given (a Docker or systemd secret
  # mount); anything else is resolved under config/, as it always was. A bare
  # Errno::ENOENT at boot names no path, so say which file we looked for.
  def self.read_pem_file(pem_name)
    path = Pathname.new(pem_name)
    path = Rails.root.join('config', path) unless path.absolute?
    unless path.exist?
      raise "PayPal pem file not found at #{path} (from PAYPAL_PEM_FILE or the paypal.pem_file credential)"
    end

    path.read
  end

  def self.recurring_gateway(requested_gateway = nil)
    requested_gateway ||= default_recurring_gateway
    gateway(requested_gateway)
  end

  def self.gateway(requested_gateway = nil)
    requested_gateway ||= default_gateway
    case requested_gateway
    when 'paypal'
      # A blank signature omits the key entirely rather than passing "", which
      # is what selects PayPal's legacy certificate API in ActiveMerchant --
      # the same distinction the old `if signature.nil?` branch drew, now also
      # covering a signature that is present but empty.
      options = { login: AppSecrets[:paypal_login], password: AppSecrets[:paypal_password] }
      signature = AppSecrets[:paypal_signature]
      options[:signature] = signature if signature
      ActiveMerchant::Billing::PaypalGateway.new(**options)
    when 'paypal_express'
      # Express has always shared paypal's password; it now has a key of its own
      # (PAYPAL_EXPRESS_PASSWORD / paypal_express.password) and falls back.
      ActiveMerchant::Billing::PaypalExpressGateway.new(
        login: AppSecrets[:paypal_express_login],
        password: AppSecrets[:paypal_express_password] || AppSecrets[:paypal_password]
      )
    when 'stripe'
      Stripe.api_key = AppSecrets[:stripe_secret_key]
      StripeGateway.new(login: Stripe.api_key)

    when 'bogus'
      PaymentProcessing::BogusGateway.new
    end
  end

  def self.create_subscription(order)
    gateway.create_subscription(order)
  end

  def self.credit_card(card_type, first_name, last_name, card_number, card_expiration_month, card_expiration_year,
                       verification_number)
    if Rails.configuration.x.payment_config.key?('test_credit_card')
      Rails.logger.debug { "Using test credit card number of #{Rails.configuration.x.payment_config['test_credit_card']}" }
    end
    credit_card = ActiveMerchant::Billing::CreditCard.new(
      brand: credit_card_type(card_type),
      first_name: first_name,
      last_name: last_name,
      number: Rails.configuration.x.payment_config.key?('test_credit_card') ? Rails.configuration.x.payment_config['test_credit_card'].to_s : card_number,
      month: card_expiration_month,
      year: card_expiration_year,
      verification_value: verification_number
    )
    unless credit_card.valid?
      raise InvalidCreditCard, credit_card.errors.map { |field, message|
        "#{field} #{message}"
      }.join(', ')
    end

    credit_card
  end

  def self.default_recurring_gateway
    Rails.configuration.x.payment_config['default_recurring_gateway']
  end

  def self.default_gateway
    Rails.configuration.x.payment_config['default_gateway']
  end

  def self.subscription_url(subscription_id)
    gateway.subscription_url(subscription_id)
  end

  def self.product_url(price_id)
    gateway.product_url(price_id)
  end

  def self.credit_card_type(ctype)
    return Rails.configuration.x.payment_config['test_card_brand'] if Rails.configuration.x.payment_config.key?('test_card_brand')

    case ctype
    when 'MasterCard'
      'master'
    when 'master_card'
      'master'
    when 'American Express'
      'american_express'
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
