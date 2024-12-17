class ProductionPerformanceOrdersController < ApplicationController

  include OrdersHelper
  include TicketOrdersHelper

  def new
    @production = Production.find(params[:production_id])
    @performance = @production.performances.find(params[:performance_id]) unless @production.nil?
    if @production.nil? || @performance.nil? || @performance.inactive? || @production.inactive? || @performance.performance_date.past?
      respond_to do |format|
        format.html { render '/orders/not_available', :layout=>$SERVER_CONFIG['ext_site_wrapper']}
      end
    else
      @ticket_order = create_ticket_order_for_performance(@performance)
      # Debug logging
      Rails.logger.info "Marketing source from params: #{params.dig(:ticket_order, :marketing_source).inspect}"
      Rails.logger.info "Referral code cookie: #{cookies['referral_code'].inspect}"
      
      # Set special offer code from cookie only if not provided in params (including blank)
      if !params.dig(:ticket_order, :special_offer_code) && cookies['spofrcode'].present?
        @ticket_order.special_offer_code = cookies['spofrcode']
      end
      
      # Set marketing source from referral_code only if not already set in params
      if !params.dig(:ticket_order, :marketing_source)
        if params[:referral_code].present?
          @ticket_order.marketing_source = params[:referral_code].to_s
        elsif cookies['referral_code'].present?
          @ticket_order.marketing_source = cookies['referral_code'].to_s
        end
      end
      
      # Check both cookie and URL parameter for referral code
      @has_referral_cookie = cookies['referral_code'].present? || params[:referral_code].present?
      
      @order_for_to_s = @production.name + ' on ' + @performance.performance_date.to_formatted_s(:long_ordinal) +
          ' at ' + @performance.performance_time.to_formatted_s(:hour_min)

      respond_to do |format|
        format.html { render '/ticket_orders/edit', :layout=>$SERVER_CONFIG['ext_site_wrapper'] }
      end
    end
  end

end