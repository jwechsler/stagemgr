require "active_merchant/billing/rails"
require 'json'
module PaymentProcessing

  class BogusResponse < ActiveMerchant::Billing::Response

    PROFILE_ID = 'TEST_PROFILE_ID'

  end

  class StripeGateway < ActiveMerchant::Billing::StripePaymentIntentsGateway

    private
    def self.billing_address_hash(address) 
      billing_address = {  
        "line1": address.line1,
        "line2": address.line2,
        "city": address.city,
        "state": address.state,
        "postal_code": address.zipcode 
      }
    end

    def self.create_customer(address) 
      customer = Stripe::Customer.create({
          "name": address.full_name,
          "address": StripeGateway.billing_address_hash(address),
          "metadata": {
              "stagemgr_id": address.id
          },
          "email": address.email,
          "phone": address.phone
        })
      address.processor_id = customer.id
      customer
    end

    public
    def create_subscription(order)
      price_id = order.recurring_offer.price_id
      price = Stripe::Price.retrieve(price_id)
      product = Stripe::Product.retrieve(price.product)
      f_name, m_name, l_name = order.address.parse_full_name
      order.credit_card_expiration_year = Order.fix_expiration_year(order.credit_card_expiration_year.to_s)
      credit_card = PaymentProcessing.credit_card(  order.credit_card_type,
                                                  f_name,
                                                  l_name,
                                                  order.credit_card_number,
                                                  order.credit_card_expiration_month,
                                                  order.credit_card_expiration_year,
                                                  order.credit_card_verification_number)
      payment_method = Stripe::PaymentMethod.create({
        type: 'card',
        card: {
          number: credit_card.number,
          exp_month: credit_card.month,
          exp_year: credit_card.year,
          cvc: credit_card.verification_value
        },
        billing_details: {
          address: StripeGateway.billing_address_hash(order.address),
        }
      })
      if order.address.processor_id.blank? then
        customer = StripeGateway.create_customer(order.address)
      else
        begin
          customer = Stripe::Customer.retrieve(customer.processor_id)
        rescue Stripe::InvalidRequestError
          customer = StripeGateway.create_customer(order.address)
        end
      end
      order.address.processor_id = customer.id
      Stripe::PaymentMethod.attach(
        payment_method.id,
        {customer: customer.id})
      customer = Stripe::Customer.update(order.address.processor_id,
      {
        invoice_settings: {
          default_payment_method: payment_method.id,
          custom_fields: [{
            name: 'subscription_order',
            value: order.id
          }]
        }
      })
      subscription = Stripe::Subscription.create({
        customer: customer.id,
        payment_behavior: "error_if_incomplete",
        items: [ "price": price_id ]
      })
      return subscription.id
    end

    def subscription(subscription_id)
      Stripe::Subscription.retrieve(subscription_id)
    end

    def subscription_url(subscription_id)
      if subscription_id.starts_with?('sub')
        if Stripe.api_key.starts_with?('sk_test')
          base_url = "https://dashboard.stripe.com/test/subscriptions/"
        else 
          base_url = "https://dashboard.stripe.com/subscriptions/"
        end
      else
        base_url = "https://www.paypal.com/billing/subscriptions/"
      end
      "#{base_url}#{subscription_id}"
    end

    def product_url(price_id)
      if Stripe.api_key.starts_with?('sk_test')
        base_url = "https://dashboard.stripe.com/test/prices/"
      else 
        base_url = "https://dashboard.stripe.com/prices/"
      end
      "#{base_url}#{price_id}"
    end
  end

  class BogusGateway < ActiveMerchant::Billing::BogusGateway
    class_attribute :profiles

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
    if $PAYMENT_CONFIG.has_key?('stripe') then
      Stripe.api_key=$PAYMENT_CONFIG['stripe']['secret_key']
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
      if $PAYMENT_CONFIG['paypal']['signature'].nil? then
        ActiveMerchant::Billing::PaypalGateway.new(:login=>$PAYMENT_CONFIG['paypal']['login'],
          :password=>$PAYMENT_CONFIG['paypal']['password'])
      else
        ActiveMerchant::Billing::PaypalGateway.new(:login=>$PAYMENT_CONFIG['paypal']['login'],
          :password=>$PAYMENT_CONFIG['paypal']['password'],
          :signature=>$PAYMENT_CONFIG['paypal']['signature'])
      end
    when 'paypal_express'
      ActiveMerchant::Billing::PaypalExpressGateway.new(:login=>$PAYMENT_CONFIG['paypal_express']['login'],
        :password=>$PAYMENT_CONFIG['paypal_express']['password'])
    when 'stripe'
      Stripe.api_key=$PAYMENT_CONFIG['stripe']['secret_key']
      StripeGateway.new(:login=>$PAYMENT_CONFIG['stripe']['secret_key'])
      
    when 'bogus'
        PaymentProcessing::BogusGateway.new
    end
  end

  def self.create_subscription(order)
    gateway.create_subscription(order)
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
    raise InvalidCreditCard, credit_card.errors.full_messages.join(", ") unless credit_card.valid?
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

end


