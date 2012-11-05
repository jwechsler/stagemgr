require 'ostruct'

class PayPalController < ApplicationController

  PAYPAL_DATETIME_FORMAT = '%H:%M:%S %b %d, %Y %Z'
  protect_from_forgery :except => :paypal_ipn



  include ActiveMerchant::Billing::Integrations

  protect_from_forgery :except => :paypal_ipn


  def referenced_membership(params)
    profile_id = params['recurring_payment_id']

    membership = Membership.find_by_profile_id(profile_id)
    raise "Cannot locate membership with payment ID '#{profile_id}'" if membership.nil?
    membership
  end

  def create_membership_payment(params)

    membership = referenced_membership(params)

      order = membership.membership_order
      processed_on = DateTime.strptime(params['payment_date'], PAYPAL_DATETIME_FORMAT).in_time_zone(Time.zone)
      payment_fee = params['payment_fee'].to_f
      amount = params['amount'].to_f
      transaction_id = params['txn_id']
      ipn_track_id = params['ipn_track_id']
      order.create_recurring_payment("IPN: #{params['txn_type']}", :amount=>amount, :processed_on=>processed_on, :transaction_id=>transaction_id, :payment_fee=>payment_fee, :ipn_track_id=>ipn_track_id)
      order.save!
      membership.update_from_profile!


  end

  def suspend_membership(params)

    membership = referenced_membership(params)

      membership.status = Membership::SUSPENDED
      membership.save!

  end

  def cancel_membership(params)
     membership = referenced_membership(params)

      membership.status = Membership::CANCELED
      membership.save!
  end

  def record_standard_payment(params)
    o = Order.find(params['invoice'].to_i)
    raise "Could not find order #{params['invoice']}" if o.nil?
    p = Payment.find_by_transaction_id_and_order_id(params['txn_id'], params['invoice'].to_i)
    raise "Could not find payment with transaction #{params['transaction_id']}" if p.nil?
    raise "Mismatched payment/order combination.  Payment #{p.id} does not match order #{o.id}" if p.order_id != o.id
    p.ipn_track_id = params['ipn_track_id']
    p.payment_fee = params['payment_fee'].to_f
    p.save!
  end


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

        create_membership_payment(params)

      elsif txn_type == 'recurring_payment_suspended'

        suspend_membership(params)

      elsif txn_type == 'recurring_payment_profile_cancel'

        cancel_membership(params)

      elsif txn_type == 'web_accept'
        record_standard_payment(params)

      else
        logger.warn("Unhandled IPN request: #{params.to_yaml}")
      end



      render :text => 'OK'



    else

      render :text => 'ERROR' + '/n' + response.to_yaml

    end

  end

end


