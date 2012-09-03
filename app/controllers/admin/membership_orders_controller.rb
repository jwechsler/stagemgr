class Admin::MembershipOrdersController < Admin::ApplicationController
  filter_resource_access
  include ::OrdersHelper
  include ::MembershipOrdersHelper

  def show
    @order = MembershipOrder.find(params[:id])
  end

  def create

    success = create_membership

    if success
      flash[:notice] = raw "Customer successfully set up for the <strong>#{@order.membership_offer.name}</strong> payment plan."
    else
      render '/admin/membership_orders/edit'
      return
    end

    render '/admin/membership_orders/show'

  end

  def edit

  end



  
end