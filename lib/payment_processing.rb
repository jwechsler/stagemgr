module PaymentProcessing

  class BogusResponse < ActiveMerchant::Billing::Response
    def initialize(original_response)
      super(original_response.success?, original_response.message, original_response.params)
    end

    def authorization
      '12345'
    end
  end

  class BogusGateway < ActiveMerchant::Billing::BogusGateway
      def purchase(money, creditcard, options = {})
        response = BogusResponse.new(super(money, creditcard, options))
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
      ActiveMerchant::Billing::PaypalGateway.new(:login=>$PAYMENT_CONFIG['paypal']['login'],
        :password=>$PAYMENT_CONFIG['paypal']['password'])
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


