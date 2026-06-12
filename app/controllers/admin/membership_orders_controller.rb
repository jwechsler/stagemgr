class Admin::MembershipOrdersController < Admin::ApplicationController
  load_and_authorize_resource
  include ::OrdersHelper
  include ::MembershipOrdersHelper
  include ActionView::Helpers::OutputSafetyHelper

  def show
    @membership_order.membership.update_from_profile!
  rescue Exception => e
    Rails.logger.warn("Recurring Payment for order #{params[:id]} not updated. #{e.message}")
  end

  def reactivate
    result = @membership_order.reactivate
    if result.success?
      flash[:notice] = "Membership reactivated. #{result.message}"
    else
      flash[:error] = "#{result.message}"
    end
    render '/admin/membership_orders/show'
  end

  def cancel
    result = @membership_order.cancel
    if result.success?
      flash[:notice] = "Membership cancelled. #{result.message}"
    else
      flash[:error] = "#{result.message}"
    end
    render '/admin/membership_orders/show'
  end

  def edit; end

  def create
    update_or_create
  end

  def update
    @membership_order.update(membership_order_params)
    update_or_create
  end

  def update_seating
    @membership_order.membership.preferred_seating = params[:membership_order][:membership][:preferred_seating]
    @membership_order.membership.save!
    respond_to do |format|
      format.html { render 'show' }
    end
  end

  def fulfill
    @membership_order.transition_to(Order::FULFILLED)
    respond_to do |format|
      format.html { render 'show' }
    end
  end

  protected

  def update_or_create
    respond_to do |format|
      if validate_web_order(@membership_order) && process_order(@membership_order, Order::PROCESSED)
        flash[:info] =
          raw "Customer successfully set up for the <strong>#{@membership_order.membership_offer.name}</strong> payment plan."
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
