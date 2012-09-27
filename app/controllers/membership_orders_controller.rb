class MembershipOrdersController < ApplicationController
  layout 'ext_site_wrapper'
  include OrdersHelper
  include MembershipOrdersHelper

  def create
    success = self.create_membership

    if success
      flash[:notice] = raw "You've been successfully set up for the <strong>#{@order.membership_offer.name}</strong> payment plan."
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
