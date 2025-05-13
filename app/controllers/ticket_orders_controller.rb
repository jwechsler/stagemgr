# This controller handles the public-facing ticket ordering process.
# It manages the creation and editing of ticket orders, including:
# - Setting marketing source from referral cookies
# - Handling special offer codes
# - Processing order submissions
class TicketOrdersController < ApplicationController
  layout $SERVER_CONFIG['ext_site_wrapper']
  include TicketOrdersHelper

  # No login requirement since this is a public controller
  before_action :find_order, :only => [:show, :edit, :update, :destroy, :confirm]
  before_action :redirect_to_proper_action, :only => [:edit]
  # skip_before_action :verify_authenticity_token, :only => [:create]

  respond_to :html

  def edit
    preset_line_items_for_display(@ticket_order)
    # Check both cookie and URL parameter for referral code
    @has_referral_cookie = cookies['referral_code'].present? || params[:referral_code].present?
    
    # Store referral code in a secure cookie with proper settings
    # - Converts to string to avoid type errors
    # - Sets proper expiration (2 days)
    # - Uses secure flag in production
    # - Sets httponly to prevent JavaScript access
    if params[:referral_code].present?
      cookies['referral_code'] = {
        value: params[:referral_code].to_s,
        expires: 2.days.from_now,
        secure: Rails.env.production?,
        httponly: true
      }
    end
    
    # Set marketing source from referral_code cookie if present and marketing_source isn't already set
    # This system integrates with external referral tracking systems or campaigns
    if @has_referral_cookie && @ticket_order.marketing_source.blank?
      referral = cookies['referral_code'].to_s
      # Set the marketing source directly - the validation in the model will ensure it's safe
      # Note: REFERRALS list is for reporting/UI purposes and custom referral codes are also valid
      @ticket_order.marketing_source = referral
    end
  end

  def create
    @ticket_order = TicketOrder.new(ticket_order_params)
    @ticket_order.uuid = params[:ticket_order][:uuid] unless params[:ticket_order][:uuid].blank?
    @ticket_order.ip_address = request.remote_ip
    @ticket_order.create_default_service_fees
    @ticket_order.status = Order::NEW
    
    # Set special offer code from cookie only if not provided in params (including blank)
    if !params[:ticket_order].key?(:special_offer_code) && cookies['spofrcode'].present?
      @ticket_order.special_offer_code = cookies['spofrcode']
      # Delete cookie securely
      cookies.delete('spofrcode', secure: Rails.env.production?, httponly: true)
    end
    
    # Set marketing source from referral_code cookie only if not provided in params (including blank)
    if !params[:ticket_order].key?(:marketing_source) && cookies['referral_code'].present?
      # Ensure referral is always a string to avoid =~ error on integers
      referral = cookies['referral_code'].to_s
      # Set the marketing source directly - the validation in the model will ensure it's safe
      # Note: REFERRALS list is for reporting/UI purposes and custom referral codes are also valid
      @ticket_order.marketing_source = referral
    end
    
    update_or_create
  end

  def update
    # @ticket_order = TicketOrder.find(params[:id].to_i)
    @ticket_order.update(ticket_order_params)
    @ticket_order.ip_address = request.remote_ip
    # @ticket_order_for_to_s = @ticket_order.performance.production.name + ' on ' + @ticket_order.performance.performance_date.to_formatted_s(:long_ordinal) +
    #      ' at ' + @ticket_order.performance.performance_time.to_formatted_s(:hour_min)
    update_or_create
  end

  def confirm
    # @ticket_order = TicketOrder.find(params[:id].to_i)
  end

  def show
    @ticket_order = TicketOrder.find(params[:id].to_i)
    respond_to do |format|
      format.html { render '/general/unavailable'}
    end
  end

#  def donate
#    @ticket_order = TicketOrder.new(ticket_order_params)
#  end

  private
  def update_or_create
    respond_to do |format|
      if !params[:commit].blank? && validate_web_order(@ticket_order) && process_order(@ticket_order, convert_button_label_to_state(params[:commit]))
        # Clear the special offer cookie if order is processed
        if @ticket_order.processing? || @ticket_order.processed?
          cookies.delete('spofrcode', secure: Rails.env.production?, httponly: true)
        end
        
        if @ticket_order.processing?
          format.html { render '/ticket_orders/confirm' }
        else
          format.html { render '/ticket_orders/show' }
        end

      else
        if @ticket_order.finalized?
          format.html { render 'show'}
        else
          preset_line_items_for_display(@ticket_order)
          if @ticket_order.processing? || @ticket_order.new?
            format.html { render '/ticket_orders/edit' }
          else
            format.html { render '/general/unavailable' }
          end
        end
      end
    end
  end

  def find_order
    @ticket_order = TicketOrder.find(params[:id].to_i)
  end

  def redirect_to_proper_action
    flash.keep
    if @ticket_order.editable?
      if params[:action] != 'edit'
        redirect_to(edit_ticket_order_path(@ticket_order))
      end
    else
      if params[:action] != 'show'
        redirect_to(ticket_order_path(@ticket_order))
      end
    end
  end

  private
  def ticket_order_params
    params.require(:ticket_order).permit(*ticket_order_common_params)
  end
end
