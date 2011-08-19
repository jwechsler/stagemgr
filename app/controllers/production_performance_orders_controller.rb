class ProductionPerformanceOrdersController < ApplicationController
  def new
    @production = Production.find(params[:production_id])
    @performance = @production.performances.find(params[:performance_id]) unless @production.nil?
    if @production.nil? || @performance.nil? || @performance.inactive?
      respond_to do |format|
        format.html { render '/orders/not_available', :layout=>'ext_site_wrapper'}
      end
    else
      @available_ticket_classes = @performance.ticket_class_allocations.select { |tca| tca.available }.map { |tca| tca.ticket_class }.select { |tc| tc.web_visible unless tc.nil? }
      @order = @performance.orders.build(:status=>Order::WEB)
      @order.status = Order::NEW
      @order.address = Address.new
      @available_ticket_classes.each { |tc| @order.ticket_line_items.build(:ticket_class=>tc) }
      # @order.donation_line_items.build(:donation_amount=>0)
      @order_for_to_s = @production.name + ' on ' + @performance.performance_date.to_formatted_s(:long_ordinal) +
          ' at ' + @performance.performance_time.to_formatted_s(:hour_min)

      respond_to do |format|
        format.html { render '/orders/edit', :layout=>'ext_site_wrapper' }
      end
    end
  end
end