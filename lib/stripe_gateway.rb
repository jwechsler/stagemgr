class StripeGateway
  #
  # Not used currently. Delete?
  #

  def credit_card(card_type, first_name, last_name, card_number, card_expiration_month, card_expiration_year, verification_number)
    return Stripe::PaymentMethod.create({
      type: 'card',
      card: {
        number: card_number,
        exp_month: card_expiration_month,
        exp_year: card_expiration_year,
        cvc: verification_number,
      },
    })
  end

  def self.api_key=(api_key) 
    Stripe.api_key = api_key
  end

  def purchase(money, credit_card, options = {})

    billing_address = options[:billing_address]

    payment_method = Stripe::PaymentMethod.create({
      type: 'card',
      card: {
        number: credit_card[:number],
        exp_month: 7,
        exp_year: 2022,
        cvc: '314',
      },
    })
    
      charge = Stripe::Charge.create({
        amount: money,
        currency: 'usd',
        billing_details: {
          address: {
            city: billing_address[:city],
            line1: billing_address[:address1],
            line2: billing_address[:address2],
            state: billing_address[:state],
            postal_code: billing_address[:zip],
            
          },
          phone: billing_address[:phone],
          email: options[:email],
          name: billing_address[:name]
        },
        description: options[:description],
        invoice: options[:order_id],
        source: credit_card
      })
    Rails.logger.debug(charge.to_yaml)
  end
end
