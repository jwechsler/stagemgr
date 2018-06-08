class MembershipOrdersController < ApplicationController
  layout 'ext_site_wrapper'
  include OrdersHelper
  include MembershipOrdersHelper

  def payment_types_for(order, frontend = true)
    types = super
    types.select{|t| t.is_a? CreditCardPaymentType}
  end

  def create
    success = self.create_membership

    if success
      flash[:notice] = raw "You've been successfully set up for the <strong>#{@order.membership_offer.name}</strong> payment plan."
    else
      render '/membership_orders/edit'
    end

  end

  def update
    @order = MembershipOrder.new(membership_order_params)
    process_order(@order,:confirm_membership_order_path)
  end

  def show
  end

  def edit
    @order = MembershipOrder.find(params[:id])
  end



  def checkout
  end

  private
  def membership_order_params
    params.require(:membership_order).permit(*common_params, *common_membership_order_params)
  end

end
