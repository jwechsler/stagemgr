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
      # Set special offer code from cookie if not already set
      if @ticket_order.special_offer_code.blank? && cookies['spofrcode'].present?
        @ticket_order.special_offer_code = cookies['spofrcode']
        @ticket_order.save
      end
      
      @order_for_to_s = @production.name + ' on ' + @performance.performance_date.to_formatted_s(:long_ordinal) +
          ' at ' + @performance.performance_time.to_formatted_s(:hour_min)

      respond_to do |format|
        format.html { render '/ticket_orders/edit', :layout=>$SERVER_CONFIG['ext_site_wrapper'] }
      end
    end
  end

end