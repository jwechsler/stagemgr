class MembershipOrdersController < ApplicationController
  layout 'ext_site_wrapper'
  include OrdersHelper

  def create
    @order = MembershipOrder.new(params[:membership_order])
    @order.ip_address = request.remote_ip
    @order.transition_to!(Order::PROCESSING)
    gateway ||= PaymentProcessing.recurring_gateway
    membership_offer = @order.membership_offer

    credit_card = PaymentProcessing.credit_card(@order.credit_card_type,
                                                @order.address.first_name,
                                                @order.address.last_name,
                                                @order.credit_card_number,
                                                @order.credit_card_expiration_month,
                                                @order.credit_card_expiration_year,
                                                @order.credit_card_verification_number)

    response = gateway.recurring((membership_offer.recurring_cost * 100).to_i, credit_card, 
      :ip=>@order.ip_address, :order_id =>@order.id, 
      :description => membership_offer.billing_agreement, :start_date=>Date.today,
      :period=>'Month', :frequency=>1)
    if response.success?
      profile_id = response.params["profile_id"]
      membership = @order.membership
      membership.profile_id = profile_id
      membership.status = response.params["profile_status"][0..-8]
      membership.save!
      @order.transition_to!(Order::PROCESSED)
      flash[:notice] = raw "Your PayPal account was successfully set up for the <strong>#{membership_offer.name}</strong> payment plan."
    else
      flash.now[:notice] = "There was a problem setting up your PayPal account for the <strong>#{membership_offer.name}</strong> payment plan"
      render url_for(:controller=>:membership_orders, :id => @order.id, :action=>:edit)
    end

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
    gateway ||= PaymentProcessing.recurring_gateway

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
