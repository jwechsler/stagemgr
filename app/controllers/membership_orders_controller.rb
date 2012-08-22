class MembershipOrdersController < ApplicationController
  layout 'ext_site_wrapper'
  include OrdersHelper

  def create
    begin
      MembershipOrder.transaction do
        @order = MembershipOrder.new(params[:membership_order])
        @order.ip_address = request.remote_ip
        @order.transition_to!(Order::PROCESSING)

        gateway ||= PaymentProcessing.recurring_gateway
        membership_offer = @order.membership_offer
        f_name, m_name, l_name = @order.address.parse_full_name

        credit_card = PaymentProcessing.credit_card(@order.credit_card_type,
                                                    f_name,
                                                    l_name,
                                                    @order.credit_card_number,
                                                    @order.credit_card_expiration_month,
                                                    @order.credit_card_expiration_year,
                                                    @order.credit_card_verification_number)

        response = gateway.recurring((membership_offer.recurring_cost * 100).to_i, credit_card,
                                     :ip=>@order.ip_address, :order_id =>@order.id, :email=>@order.address.email,
                                     :description => membership_offer.billing_agreement, :start_date=>Date.today,
                                     :period=>'Month', :frequency=>1, :max_failed_payments=>1, :auto_bill_outstanding=> true)
        success = response.success?
        if response.success?
          profile_id = response.params["profile_id"]
          membership = @order.membership
          membership.profile_id = profile_id
          membership.status = response.params["profile_status"][0..-8]
          membership.save!
          @order.transition_to!(Order::PROCESSED)
        else
          flash[:error] = "There was a problem setting up your PayPal account for the <strong>#{membership_offer.name}</strong> payment plan. #{response.message}"
        end
      end
    rescue Exception=> e
      success = false

      flash[:error] = e.message
    end

    if success
      flash[:notice] = raw "You've been successfully set up for the <strong>#{membership_offer.name}</strong> payment plan."
    else
      render '/membership_orders/edit'
    end

  end

  def update
    @order = MembershipOrder.new(params[:membership_order])
    process_order(@order,:confirm_membership_order_path)
  end

  def show
  end

  def edit
    @order = MembershipOrder.find(params[:id])
  end



  def checkout
  end


end
