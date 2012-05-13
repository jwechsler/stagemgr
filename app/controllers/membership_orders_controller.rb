class MembershipOrdersController < ApplicationController
  layout 'ext_site_wrapper'
  include OrdersHelper

  def create
    @order = MembershipOrder.new(params[:membership_order])
    @order.transition_to!(Order::PROCESSING)
    gateway ||= ActiveMerchant::Billing::PaypalRecurringGateway.new(:login=>$PAYPAL_LOGIN,
                                                                    :password=>$PAYPAL_PASSWORD)
    membership_offer = @order.membership_offer

    setup_response = gateway.setup_authorization((membership_offer.recurring_cost * 100).to_i,
                                                 :ip => request.remote_ip,
                                                 :return_url => url_for(:controller=>:membership_orders, :id=>@order.id, :action=>:confirm, :only_path=>false),
                                                 :cancel_return_url => "http://www.theaterwit.org",
                                                 :description => membership_offer.billing_agreement)

    redirect_to gateway.redirect_url_for(setup_response.token)
  end

  def update
    @order = MembershipOrder.new(params[:membership_order])
    process_order(@order,:confirm_membership_order_path)
  end

  def show
  end

  def edit
  end

  def confirm
    @order = MembershipOrder.find(params[:id])
    token = params[:token]
    offer = @order.membership.membership_offer
    gateway ||= ActiveMerchant::Billing::PaypalRecurringGateway.new(:login=>$PAYPAL_LOGIN,
                                                                        :password=>$PAYPAL_PASSWORD)

    response = gateway.create_profile(token,
                                      :description => offer.billing_agreement,
                                      :start_date => Date.today,
                                      :frequency => 1,
                                      :amount => (offer.recurring_cost*100).to_i,
                                      :auto_bill_outstanding => false,
                                      :max_failed_payments => 1)


    if response.success?
      profile_id = response.params["profile_id"]
      membership = @order.membership
      membership.profile_id = profile_id
      membership.status = response.params["profile_status"][0..-8]
      membership.save!
      @order.transition_to!(Order::PROCESSED)
      flash[:notice] = "Your PayPal account was successfully set up for the <strong>#{offer.name}</strong> payment plan."
    else
      flash.now[:notice] = "There was a problem setting up your PayPal account for the <strong>#{offer.name}</strong> payment plan"
      render url_for(:controller=>:membership_orders, :id => @order.id, :action=>:edit)
    end

  end

  def checkout
  end


end
