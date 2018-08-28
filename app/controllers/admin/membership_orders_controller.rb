class Admin::MembershipOrdersController < Admin::ApplicationController
  load_and_authorize_resource
  include ::OrdersHelper
  include ::MembershipOrdersHelper

  def show
    @order = @membership_order
    begin
      @order.membership.update_from_profile!
    rescue SocketError => e
      Rails.logger.warn("Recurring Payment for order #{params[:id]} not updated.  Socket Error")
    end
  end

  def reactivate
    @order = @membership_order
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
    @order = @membership_order
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
    success = create_membership(@membership_order)
    @order = @membership_order
    if success
      flash[:notice] = raw "Customer successfully set up for the <strong>#{@membership_order.membership_offer.name}</strong> payment plan."
    else
      render '/admin/membership_orders/edit'
      return
    end

    render '/admin/membership_orders/show'

  end

  def edit

  end

  private
  def membership_order_params
    params.require(:membership_order).permit(*common_params, *common_membership_order_params)
  end

end