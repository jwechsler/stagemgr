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

  events.subscribe 'charge.refunded' do |event|
    invoice_id = event.data['object']['invoice']
    # Only subscription invoices are booked here; one-off charges (including
    # exchange refunds) are recorded by the app. Without this guard a nil
    # invoice would match an unrelated payment with no transaction_id.
    next if invoice_id.blank?

    payment = Payment.find_by(transaction_id: invoice_id)
    unless payment.nil?
      refund_payment = payment.dup
      refund_payment.amount = CurrencyUtils.float_to_currency_decimal(BigDecimal(event.data['object']['amount_refunded'].to_s) / -100.0)
      refund_payment.note = 'Refund'
      refund_payment.save!
      Rails.logger.debug { "REFUNDED payment from STRIPE #{refund_payment.id}" }
    end
  end

  events.all do |event|
    Rails.logger.debug("STRIPE CALLBACK: #{event.type}\n\t#{event.data.object}")
  end
end
