require 'ostruct'

class PayPalController < ApplicationController

  PAYPAL_DATETIME_FORMAT = '%H:%M:%S %b %d, %Y %Z'
  protect_from_forgery :except => :paypal_ipn



  include ActiveMerchant::Billing::Integrations

  protect_from_forgery :except => :paypal_ipn


  # process the PayPal IPN POST

  def paypal_ipn

    # use the POSTed information to create a call back URL to PayPal

    query = 'cmd=_notify-validate'

    request.params.each_pair {|key, value| query = query + '&' + key + '=' +

      value if key != 'register/pay_pal_ipn.html/pay_pal_ipn' }



    paypal_url = 'www.paypal.com'

    if ENV['RAILS_ENV'] == 'development'

      paypal_url = 'www.sandbox.paypal.com'

    end



    # Verify all this with paypal

   http = Net::HTTP.start(paypal_url, 80)

   response = http.post('/cgi-bin/webscr', query)

   http.finish



    item_name = params[:item_name]

    item_number = params[:item_number]

    payment_status = params[:payment_status]

    txn_type = params[:txn_type]

    custom = params[:custom]


    valid = response && response.body.chomp == 'VERIFIED'
#valid = true
    # Paypal confirms so lets process.

#    if response && response.body.chomp == 'VERIFIED'
    if valid

      if txn_type == 'recurring_payment'

        Resque.enqueue(ProcessRecurringPaypalPayment, params)

      elsif txn_type == 'recurring_payment_suspended'

        Resque.enqueue(SuspendRecurringPaypalPayment, params)

      elsif txn_type == 'recurring_payment_profile_cancel'

        Resque.enqueue(CancelRecurringPaypalPayment, params)

      elsif txn_type == 'web_accept'
        Resque.enqueue_in(5.seconds, ProcessPaypalPayment, params)

      else
        logger.warn("Unhandled IPN request: #{params.to_yaml}")
      end



      render :text => 'OK'



    else

      render :text => 'ERROR'
	#  + '/n' + response.to_yaml

    end

  end

end


