module PaymentProcessing


  class BogusResponse < ActiveMerchant::Billing::Response

    PROFILE_ID = 'TEST_PROFILE_ID'
    def initialize(original_response)
      super(original_response.success?, original_response.message, original_response.params)
      @custom_fields = {}
    end

    def authorization
      '12345'
    end

  end

  class BogusGateway < ActiveMerchant::Billing::BogusGateway
    class_attribute :profiles

    def purchase(money, creditcard, options = {})
      response = BogusResponse.new(super(money, creditcard, options))
    end

    def recurring(money, credit_card, options={})
      response = super(money, credit_card, options)
      response = BogusResponse.new(super(money, credit_card, options))
      response.params['profile_id'] = BogusResponse::PROFILE_ID
      response.params['profile_status'] = 'ActiveProfile'
      BogusGateway.profiles = Hash.new if BogusGateway.profiles.nil?
      if BogusGateway.profiles[BogusResponse::PROFILE_ID].nil?
        balance = money
        balance = balance*options['total_billing_cycles'] if options.has_key?('cycles')
        balance = balance*options[:total_billing_cycles] if options.has_key?(:cycles)
        BogusGateway.profiles[BogusResponse::PROFILE_ID] = response.params.merge({
          'outstanding_balance'=>balance,
          'aggregate_amount'=>0,
          'number_cycles_completed'=>0,
          'final_payment_due_date'=>(options[:start_date].to_date + options[:total_billing_cycles].to_i.months)
        }).merge(options)
      end
      response
    end

    def status_recurring(profile_id)
      r = BogusResponse.new(ActiveMerchant::Billing::Response.new(true, "Forced Response"))
      r.params['profile_id'] = profile_id
      r.params['profile_status'] = 'ActiveProfile'
      r.params.merge!(BogusGateway.profiles[profile_id])
      r
    end

  end

  def self.after_initialize
    if $PAYMENT_CONFIG.has_key?('paypal') then
      if $PAYMENT_CONFIG['paypal'].has_key?('pem_file') then
        pem_file = File.read(::Rails.root.to_s+"/config/#{$PAYMENT_CONFIG['paypal']['pem_file']}")
        ActiveMerchant::Billing::PaypalGateway.pem_file = pem_file
      end
    end
    if $PAYMENT_CONFIG.has_key?('paypal_express') then
      if $PAYMENT_CONFIG['paypal_express'].has_key?('pem_file') then
        pem_file = File.read(::Rails.root.to_s+"/config/#{$PAYMENT_CONFIG['paypal_express']['pem_file']}")
        ActiveMerchant::Billing::PaypalExpressGateway.pem_file = pem_file
      end
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
      unless $PAYMENT_CONFIG['paypal']['signature'].nil? do
        ActiveMerchant::Billing::PaypalGateway.new(:login=>$PAYMENT_CONFIG['paypal']['login'],
          :password=>$PAYMENT_CONFIG['paypal']['password'],
          :signature=>$PAYMENT_CONFIG['paypal']['signature'])
      else
        ActiveMerchant::Billing::PaypalGateway.new(:login=>$PAYMENT_CONFIG['paypal']['login'],
          :password=>$PAYMENT_CONFIG['paypal']['password'])
      end
    when 'paypal_express'
      ActiveMerchant::Billing::PaypalExpressGateway.new(:login=>$PAYMENT_CONFIG['paypal_express']['login'],
        :password=>$PAYMENT_CONFIG['paypal_express']['password'])
    when 'bogus'
        PaymentProcessing::BogusGateway.new
    end
  end

  def self.credit_card(card_type, first_name, last_name, card_number, card_expiration_month, card_expiration_year, verification_number)
    credit_card = ActiveMerchant::Billing::CreditCard.new(
      :brand => credit_card_type(card_type),
      :first_name => first_name,
      :last_name => last_name,
      :number => $PAYMENT_CONFIG.has_key?('test_credit_card') ? $PAYMENT_CONFIG['test_credit_card'] : card_number,
      :month => card_expiration_month,
      :year => card_expiration_year,
      :verification_value => verification_number
    )
    raise InvalidCreditCard, credit_card.errors.full_messages.join("\n") unless credit_card.valid?
    credit_card
  end

  private

  def self.default_recurring_gateway
    $PAYMENT_CONFIG['default_recurring_gateway']
  end

  def self.default_gateway
    $PAYMENT_CONFIG['default_gateway']
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

end


