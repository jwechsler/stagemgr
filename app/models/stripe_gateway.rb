class StripeGateway < ActiveMerchant::Billing::StripePaymentIntentsGateway
  def self.billing_address_hash(address)
    {
      line1: address.line1,
      line2: address.line2,
      city: address.city,
      state: address.state,
      postal_code: address.zipcode
    }
  end

  def self.create_customer(address)
    customer = Stripe::Customer.create({
                                         name: address.full_name,
                                         address: StripeGateway.billing_address_hash(address),
                                         metadata: {
                                           stagemgr_id: address.id
                                         },
                                         email: address.email,
                                         phone: address.phone
                                       })
    address.processor_id = customer.id
    customer
  end

  def create_subscription(order)
    price_id = order.recurring_offer.price_id
    price = Stripe::Price.retrieve(price_id)
    Stripe::Product.retrieve(price.product)
    f_name, l_name = order.address.parse_full_name
    order.credit_card_expiration_year = Order.fix_expiration_year(order.credit_card_expiration_year.to_s)
    credit_card = PaymentProcessing.credit_card(order.credit_card_type,
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
                                                      address: StripeGateway.billing_address_hash(order.address)
                                                    }
                                                  })
    if order.address.processor_id.blank?
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
      { customer: customer.id }
    )
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
                                                 payment_behavior: 'error_if_incomplete',
                                                 items: [{ price: price_id }]
                                               })
    subscription.id
  end

  def subscription(subscription_id)
    Stripe::Subscription.retrieve(subscription_id)
  end

  def subscription_url(subscription_id)
    return '#' unless subscription_id&.starts_with?('sub')

    base_url = if Stripe.api_key.starts_with?('sk_test')
                 'https://dashboard.stripe.com/test/subscriptions/'
               else
                 'https://dashboard.stripe.com/subscriptions/'
               end

    "#{base_url}#{subscription_id}"
  end

  def product_url(price_id)
    base_url = if Stripe.api_key.starts_with?('sk_test')
                 'https://dashboard.stripe.com/test/prices/'
               else
                 'https://dashboard.stripe.com/prices/'
               end
    "#{base_url}#{price_id}"
  end

  def external_url(transaction_id)
    base_url = if Stripe.api_key.starts_with?('sk_test')
                 "https://dashboard.stripe.com/test/#{external_type(transaction_id)}s/"
               else
                 "https://dashboard.stripe.com/#{external_type(transaction_id)}s/"
               end

    "#{base_url}#{transaction_id}"
  end

  def external_type(transaction_id)
    if transaction_id.nil?
      'unknown'
    elsif transaction_id.starts_with?('in_')
      'invoice'
    elsif transaction_id.starts_with?('sub_')
      'subscription'
    elsif transaction_id.starts_with?('pm_')
      'payment'
    else
      'unknown'
    end
  end
end
