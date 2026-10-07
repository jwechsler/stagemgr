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

  # SUBSCRIPTION path: a recurring Stripe Price, billed by Stripe until the
  # subscription ends. Returns the subscription id (the membership's
  # profile_id). A one-time Price cannot be subscribed to; see #charge_one_time.
  def create_subscription(order)
    price_id = order.recurring_offer.price_id
    price = Stripe::Price.retrieve(price_id)
    Stripe::Product.retrieve(price.product)
    customer = prepare_customer(order)
    subscription = Stripe::Subscription.create({
      customer: customer.id,
      payment_behavior: 'error_if_incomplete',
      items: [{ price: price_id }]
    }.merge(gift_cancel_at(order)))
    subscription.id
  end

  # ONE-TIME path: a one-time Stripe Price, charged once through an invoice
  # (a Subscription accepts only recurring prices). The invoice carries the
  # price's own line item, so Stripe reports and refunds read it like any
  # membership charge, and StripeRefundRecorder finds the RecurringPayment by
  # the invoice id. Its line has no subscription, so the invoice.paid webhook
  # does not book it a second time (config/initializers/stripe.rb).
  #
  # auto_advance: false keeps Stripe from finalizing or retrying on its own
  # schedule; this call finalizes and pays it now. A failed payment voids the
  # invoice, so no open invoice is left to collect later, and re-raises for
  # MembershipOrder to report. Returns the paid invoice.
  def charge_one_time(order)
    customer = prepare_customer(order)
    # The item is attached to this invoice explicitly ('exclude'), so any other
    # pending items on the customer are never swept into the membership charge.
    invoice = Stripe::Invoice.create({ customer: customer.id,
                                       collection_method: 'charge_automatically',
                                       pending_invoice_items_behavior: 'exclude',
                                       auto_advance: false,
                                       metadata: { stagemgr_order_id: order.id } })
    Stripe::InvoiceItem.create({ customer: customer.id, invoice: invoice.id,
                                 price: order.recurring_offer.price_id })
    pay_invoice(invoice)
  end

  # Refunds a paid one-time invoice in full, for an order that failed after
  # the charge (MembershipOrder#refund_paid_one_time_invoice). +metadata+
  # carries source: CreditCardPayment::REFUND_SOURCE, so StripeRefundRecorder
  # does not book the app's own refund as a dashboard one. The idempotency key
  # keeps a retried reversal from refunding twice.
  def refund_one_time(invoice_id, metadata)
    charge_id = Stripe::Invoice.retrieve(invoice_id).charge
    Stripe::Refund.create({ charge: charge_id, metadata: metadata },
                          { idempotency_key: "one-time-reversal-#{invoice_id}" })
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

  # The billing period of a Stripe Price: its recurring interval and count,
  # or one_time when the price does not recur.
  def price_billing_period(price_id)
    recurring = Stripe::Price.retrieve(price_id).recurring
    return { interval: MembershipOffer::ONE_TIME, interval_count: nil } if recurring.nil?

    { interval: recurring.interval, interval_count: recurring.interval_count }
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

  private

  # Card -> PaymentMethod -> Customer (found or created) -> attached as the
  # customer's default, which both the subscription and the one-time invoice
  # charge. Returns the updated Stripe customer.
  def prepare_customer(order)
    payment_method = create_order_payment_method(order)
    customer = find_or_create_customer(order.address)
    order.address.processor_id = customer.id
    Stripe::PaymentMethod.attach(payment_method.id, { customer: customer.id })
    Stripe::Customer.update(customer.id,
                            {
                              invoice_settings: {
                                default_payment_method: payment_method.id,
                                custom_fields: [{
                                  name: 'subscription_order',
                                  value: order.id
                                }]
                              }
                            })
  end

  def create_order_payment_method(order)
    f_name, l_name = order.address.parse_full_name
    order.credit_card_expiration_year = Order.fix_expiration_year(order.credit_card_expiration_year.to_s)
    credit_card = PaymentProcessing.credit_card(order.credit_card_type,
                                                f_name,
                                                l_name,
                                                order.credit_card_number,
                                                order.credit_card_expiration_month,
                                                order.credit_card_expiration_year,
                                                order.credit_card_verification_number)
    Stripe::PaymentMethod.create({
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
  end

  def find_or_create_customer(address)
    return StripeGateway.create_customer(address) if address.processor_id.blank?

    Stripe::Customer.retrieve(address.processor_id)
  rescue Stripe::InvalidRequestError
    StripeGateway.create_customer(address)
  end

  def pay_invoice(invoice)
    Stripe::Invoice.finalize_invoice(invoice.id)
    Stripe::Invoice.pay(invoice.id)
  rescue Stripe::StripeError
    void_quietly(invoice.id)
    raise
  end

  # The payment error is the one to report; a void that also fails is logged
  # for the box office (the invoice is then left open, uncollected).
  def void_quietly(invoice_id)
    Stripe::Invoice.void_invoice(invoice_id)
  rescue Stripe::StripeError => e
    Rails.logger.error("StripeGateway: could not void unpaid invoice #{invoice_id} - #{e.message}")
  end

  # A gift subscription ends after the offer's max_cycles_if_gift billing
  # periods. cancel_at is anchored at now, the instant the subscription
  # starts, so it falls on a period boundary (to within the seconds the API
  # call takes) and Stripe bills full periods; proration_behavior 'none'
  # keeps Stripe from crediting or prorating a final period cut short.
  # When it ends, customer.subscription.deleted marks the membership
  # Canceled through update_from_profile!. Not a gift, or no gift length:
  # the subscription renews until canceled.
  def gift_cancel_at(order)
    return {} unless order.gift?

    offer = order.recurring_offer
    offer.sync_billing_period! unless offer.billing_period_synced?
    ends_at = offer.gift_subscription_ends_at(Time.current)
    return {} if ends_at.nil?

    { cancel_at: ends_at.to_i, proration_behavior: 'none' }
  end
end
