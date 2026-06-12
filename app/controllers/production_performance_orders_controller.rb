# This controller handles the creation of ticket orders for specific performances.
# It serves as an entry point for users browsing productions and selecting performances.
# It handles:
# - Creating new ticket orders for specific performances
# - Setting marketing source from referral cookies or URL parameters
# - Handling special offer codes from cookies
# - Setting up the order form for the customer
class ProductionPerformanceOrdersController < ApplicationController
  include OrdersHelper
  include TicketOrdersHelper

  def new
    @production = Production.find(params[:production_id])
    @performance = @production.performances.find(params[:performance_id]) unless @production.nil?
    if @production.nil? || @performance.nil? || @performance.inactive? || @production.inactive? || @performance.performance_date.past?
      respond_to do |format|
        format.html { render '/orders/not_available', :layout => $SERVER_CONFIG['ext_site_wrapper'] }
      end
    else
      begin
        @ticket_order = create_ticket_order_for_performance(@performance)
        # Debug logging
        Rails.logger.info "Marketing source from params: #{params.dig(:ticket_order, :marketing_source).inspect}"
        Rails.logger.info "Referral code cookie: #{cookies['referral_code'].inspect}"

        # Store referral code in a secure cookie with proper settings
        if params[:referral_code].present?
          cookies['referral_code'] = {
            value: params[:referral_code].to_s,
            expires: 2.days.from_now,
            secure: Rails.env.production?,
            httponly: true
          }
        end

        # Set special offer code from cookie only if not provided in params (including blank)
        if !params.dig(:ticket_order, :special_offer_code) && cookies['spofrcode'].present?
          @ticket_order.special_offer_code = cookies['spofrcode']
          # Clean up the cookie after use with security settings
          cookies.delete('spofrcode', secure: Rails.env.production?, httponly: true)
        end

        # Set marketing source from referral_code param or cookie if not already set in params
        if !params.dig(:ticket_order,
                       :marketing_source) && (params[:referral_code].present? || cookies['referral_code'].present?)
          # Ensure referral is always a string to avoid =~ error on integers
          referral = (params[:referral_code].presence || cookies['referral_code']).to_s
          # Set the marketing source directly - the validation in the model will ensure it's safe
          # Note: REFERRALS list is for reporting/UI purposes and custom referral codes are also valid
          @ticket_order.marketing_source = referral
        end

        # Check both cookie and URL parameter for referral code
        @has_referral_cookie = cookies['referral_code'].present? || params[:referral_code].present?

        @order_for_to_s = @production.name + ' on ' + @performance.performance_date.to_formatted_s(:long_ordinal) +
                          ' at ' + @performance.performance_time.to_formatted_s(:hour_min)

        respond_to do |format|
          format.html { render '/ticket_orders/edit', :layout => $SERVER_CONFIG['ext_site_wrapper'] }
        end
      rescue => e
        # Debug the error to see exactly where it's happening
        Rails.logger.error "Error in production_performance_orders_controller#new: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        render plain: "Error: #{e.message}\n\nBacktrace:\n#{e.backtrace.join("\n")}", status: 500
      end
    end
  end
end
