class Admin::MembershipOrdersController < Admin::ApplicationController
  filter_resource_access :additional_member=>{:reactivate=>:reactivate, :cancel=>:cancel}
  include ::OrdersHelper
  include ::MembershipOrdersHelper

  def show
    @order = MembershipOrder.find(params[:id])
    begin
      @order.membership.update_from_profile!
    rescue SocketError => e
      Rails.logger.warn("Recurring Payment for order #{params[:id]} not updated.  Socket Error")
    end
  end

  def reactivate
    @order = MembershipOrder.find(params[:id])
    begin
      result = @order.reactivate
      unless result.success?
        flash[:error] = "#{result.message}"
      else
        flash[:success] = "Membership reactivated. #{result.message}"
      end
      render '/admin/membership_orders/show'
    end
  end

  def cancel
    @order = MembershipOrder.find(params[:id])
    begin
      result = @order.cancel
      unless result.success?
        flash[:error] = "#{result.message}"
      else
        flash[:success] = "Membership cancelled. #{result.message}"
      end
      render '/admin/membership_orders/show'
    end
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