class ProductionPerformanceOrdersController < ApplicationController

  include OrdersHelper
  include TicketOrdersHelper

  def new
    @production = Production.find(params[:production_id])
    @performance = @production.performances.find(params[:performance_id]) unless @production.nil?
    if @production.nil? || @performance.nil? || @performance.inactive? || @production.inactive? || @performance.performance_date.past?
      respond_to do |format|
        format.html { render '/orders/not_available', :layout=>'ext_site_wrapper'}
      end
    else
      @ticket_order = create_ticket_order_for_performance(@performance)
      @order_for_to_s = @production.name + ' on ' + @performance.performance_date.to_formatted_s(:long_ordinal) +
          ' at ' + @performance.performance_time.to_formatted_s(:hour_min)

      respond_to do |format|
        format.html { render '/ticket_orders/edit', :layout=>'ext_site_wrapper' }
      end
    end
  end

end