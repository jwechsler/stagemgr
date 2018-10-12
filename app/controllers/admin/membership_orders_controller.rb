class Admin::MembershipOrdersController < Admin::ApplicationController
  load_and_authorize_resource
  include ::OrdersHelper
  include ::MembershipOrdersHelper
  include ActionView::Helpers::OutputSafetyHelper

  def show
    begin
      @membership_order.membership.update_from_profile!
    rescue SocketError => e
      Rails.logger.warn("Recurring Payment for order #{params[:id]} not updated.  Socket Error")
    end
  end

  def reactivate
    begin
      result = @membership_order.reactivate
      unless result.success?
        flash[:error] = "#{result.message}"
      else
        flash[:notice] = "Membership reactivated. #{result.message}"
      end
      render '/admin/membership_orders/show'
    end
  end

  def cancel

    begin
      result = @membership_order.cancel
      unless result.success?
        flash[:error] = "#{result.message}"
      else
        flash[:notice] = "Membership cancelled. #{result.message}"
      end
      render '/admin/membership_orders/show'
    end
  end
  def create
    update_or_create
  end

  def update
    @membership_order.update_attributes(membership_order_params)
    update_or_create
  end


  def edit

  end

  protected
  def update_or_create
    Rails.logger.debug("*** Transition to #{status}")
    respond_to do |format|
      if validate_web_order(@membership_order) && process_order(@membership_order, Order::PROCESSED)
        flash[:info] = raw "Customer successfully set up for the <strong>#{@membership_order.membership_offer.name}</strong> payment plan."
        format.html { render 'show' }
      else
        format.html { render 'edit' }
      end
    end
  end

  private
  def membership_order_params
    params.require(:membership_order).permit(*common_params, *common_membership_order_params)
  end

end