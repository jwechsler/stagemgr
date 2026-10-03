StripeEvent.signing_secret = AppSecrets[:stripe_signing_secret]

StripeEvent.configure do |events|
  # events.subscribe 'charge.failed' do |event|
  # Define subscriber behavior based on the event object
  # event.class       #=> Stripe::Event
  # event.type        #=> "charge.failed"
  # event.data.object #=> #<Stripe::Charge:0x3fcb34c115f8>
  # unless event.data['object']['lines'].nil? do
  #  event.data['object']['lines'].each  do |line|
  #    unless line['subscription'].blank?
  #      # MembershipOrder.register_payment_to_profile(line['subscription'], line['amount'])
  #    end
  #  end
  # end

  events.subscribe 'invoice.paid' do |event|
    # Rails.logger.debug("STRIPE for #{event.data['subscription']}")
    transaction_id = event.data['object']['id']
    transaction_type = event.data['object']['object']
    Rails.logger.debug { "STRIPE FOR transaction id #{transaction_id} as #{transaction_type}" }
    event.data['object']['lines'].each do |line|
      if line['subscription'].present?
        MembershipOrder.register_payment_to_profile(line['subscription'], line['amount'].to_i / 100.0,
                                                    transaction_id)
      end
    end
  end

  events.subscribe 'customer.subscription.updated' do |event|
    Membership.find_by(profile_id: event.data['object']['id'])&.update_from_profile!
  end

  events.subscribe 'customer.subscription.deleted' do |event|
    Membership.find_by(profile_id: event.data['object']['id'])&.update_from_profile!
  end

  # Refunds made in the Stripe dashboard: booked once each and the order
  # flagged for review. The app's own refunds are skipped (StripeRefundRecorder).
  events.subscribe 'charge.refunded' do |event|
    StripeRefundRecorder.call(event.data.object)
  end

  # A pending refund reaching succeeded. Older API versions name the event
  # charge.refund.updated, newer ones refund.updated; booking is idempotent,
  # so receiving both is harmless.
  %w[charge.refund.updated refund.updated].each do |type|
    events.subscribe type do |event|
      StripeRefundRecorder.call_for_refund(event.data.object)
    end
  end

  events.all do |event|
    Rails.logger.debug("STRIPE CALLBACK: #{event.type}\n\t#{event.data.object}")
  end
end
