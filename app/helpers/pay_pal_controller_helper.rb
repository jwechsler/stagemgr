module PayPalControllerHelper

  PAYPAL_DATETIME_FORMAT = '%H:%M:%S %b %d, %Y %Z'

  def self.process_paypal_ipn_request(txn_type, params)
    case txn_type
      when 'recurring_payment'
        Resque.enqueue(ProcessRecurringPaypalPayment, params)
      when 'recurring_payment_suspended'
        Resque.enqueue(ProcessSuspendRecurringPaypalPayment, params)
      when 'recurring_payment_profile_cancel'
        Resque.enqueue(ProcessCancelRecurringPaypalPayment, params)
      when 'web_accept'
        Resque.enqueue_in(5.seconds, ProcessPaypalPayment, params)
      else
        Rails.logger.warn("Unhandled IPN request: #{params.to_yaml}")
    end
    true
  end

  def process_paypal_ipn_request(txn_type, params)
    PayPalControllerHelper.process_paypal_ipn_request(txn_type, params)
  end

end