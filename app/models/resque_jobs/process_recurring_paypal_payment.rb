  class ProcessRecurringPaypalPayment < PaypalIpnJob

  @queue = :sync

  def self.perform(params)

    profile = PaypalIpnJob.referenced_profile(params)
    order = PaypalIpnJob.referenced_profile(params).recurring_order
    processed_on = DateTime.strptime(params['payment_date'],
                                     PayPalControllerHelper::PAYPAL_DATETIME_FORMAT).in_time_zone(Time.zone)
    payment_fee = params['payment_fee'].to_f
    amount = params['amount'].to_f
    transaction_id = params['txn_id']
    ipn_track_id = params['ipn_track_id']
    payments = Payment.where('ipn_track_id = ?',ipn_track_id)
    if payments.size == 0 then
      order.create_recurring_payment("IPN: #{params['txn_type']}", :amount=>amount, :processed_on=>processed_on, :transaction_id=>transaction_id, :payment_fee=>payment_fee, :ipn_track_id=>ipn_track_id)
      order.save!
    end

  end

end
