StripeEvent.signing_secret = $PAYMENT_CONFIG['stripe']['signing_secret'] # e.g. whsec_...

StripeEvent.configure do |events|
  events.subscribe 'charge.failed' do |event|
    # Define subscriber behavior based on the event object
    event.class       #=> Stripe::Event
    event.type        #=> "charge.failed"
    event.data.object #=> #<Stripe::Charge:0x3fcb34c115f8>
    event.data['object']['lines'].each  do |line| 
      unless line['subscription'].blank?
        # MembershipOrder.register_payment_to_profile(line['subscription'], line['amount'])
      end
    end
  end
  
  events.subscribe 'invoice.paid' do |event| 
    Rails.logger.debug("STRIPE for #{event.data['subscription']}")
    
    event.data['object']['lines'].each do |line| 
      MembershipOrder.register_payment_to_profile(line['subscription'], (line['amount'].to_i / 100.0)) unless line['subscription'].blank?
    end
  end

  events.all do |event|
    Rails.logger.debug("STRIPE CALLBACK: #{event.type}\n\t#{event.data.object}")
  end
end
