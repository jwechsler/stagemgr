require 'ostruct'

class PayPalController < ApplicationController
  include PayPalControllerHelper


  protect_from_forgery :except => :paypal_ipn

  include ActiveMerchant::Billing::Integrations

  protect_from_forgery :except => :paypal_ipn

  # process the PayPal IPN POST

  def paypal_ipn

    # use the POSTed information to create a call back URL to PayPal

    query = 'cmd=_notify-validate'
    request.params.each_pair {|key, value| query = query + '&' + key + '=' +
      value if key != 'register/pay_pal_ipn.html/pay_pal_ipn' }
    if ENV['RAILS_ENV'] == 'development'
      paypal_url = 'www.sandbox.paypal.com'
    else
      paypal_url = 'paypal.com'
    end

    # Verify all this with paypal
    attempts = 0
    http = nil
    begin
      attempts += 1
      http = Net::HTTP.start(paypal_url, 80)
    rescue SocketError

      if attempts <= 11
        sleep(5.seconds)
        retry
      end
    end
    response = http.post('/cgi-bin/webscr', query)
    http.finish

    txn_type = params[:txn_type]

    valid = response && response.body.chomp == 'VERIFIED'
    # Paypal confirms so lets process.
    if valid
      render :text => 'OK' if self.process_paypal_ipn_request(txn_type, params)
    else
      render :text => 'ERROR'
    end

  end


end


