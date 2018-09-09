class MembershipOrdersController < ApplicationController
  layout 'ext_site_wrapper'
  include OrdersHelper
  include MembershipOrdersHelper

  def payment_types_for(order, frontend = true)
    types = super
    types.select{|t| t.is_a? CreditCardPaymentType}
  end

  def create
    @order = MembershipOrder.new(membership_order_params)
    update_or_create
  end

  def update
    @order = MembershipOrder.find(params[:id].to_i)
    @order.update_attributes(membership_order_params)
    update_or_create
  end

  def show
  end

  def edit
    @order = MembershipOrder.find(params[:id])
  end

  def new
    @order = build_membership_order(params[:membership_offer_id].to_i)
  end



  def checkout
  end

  private
  def update_or_create
    respond_to do |format|
      if validate_web_order(@order) && process_order(@order, Order::PROCESSING) && process_order(@order, Order::PROCESSED)
        flash[:notice] = raw "You've been successfully set up for the <strong>#{@order.membership_offer.name}</strong> membership"
        format.html { render '/membership_orders/confirm' }
      else
        format.html { render '/membership_orders/edit' }
      end
    end
  end

  def membership_order_params
    params.require(:membership_order).permit(*common_params, *common_membership_order_params)
  end

end
