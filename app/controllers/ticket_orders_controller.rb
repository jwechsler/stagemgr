class TicketOrdersController < ApplicationController
  layout 'ext_site_wrapper'
  include OrdersHelper
  include TicketOrdersHelper

  append_before_filter :find_order, :only => [:show, :edit, :update, :destroy, :confirm]
  append_before_filter :redirect_to_proper_action, :only => [:edit, :show]

  respond_to :html

  def edit
    @order = TicketOrder.find(params[:id].to_i)
    preset_line_items_for_display(@order)

  end

  def create
    @order = TicketOrder.new(ticket_order_params)
    @order.ip_address = request.remote_ip
    update_or_create
  end

  def update
    @order = TicketOrder.find(params[:id].to_i)
    @order.update_attributes(ticket_order_params)
    @order.ip_address = request.remote_ip
    # @order_for_to_s = @order.performance.production.name + ' on ' + @order.performance.performance_date.to_formatted_s(:long_ordinal) +
    #      ' at ' + @order.performance.performance_time.to_formatted_s(:hour_min)
    update_or_create
  end

  def confirm
    @order = TicketOrder.find(params[:id].to_i)
  end

#  def donate
#    @order = TicketOrder.new(ticket_order_params)
#  end

  private
  def update_or_create
    respond_to do |format|
      if !params[:commit].blank? && validate_web_order(@order) && process_order(@order, convert_button_label_to_state(params[:commit]))
        if @order.processing?
          format.html { render '/ticket_orders/confirm' }
        else
          format.html { render '/ticket_orders/show' }
        end

      else
        if @order.finalized?
          format.html { render '/ticket_orders/show '}
        else
          Rails.logger.debug("*** Order status is #{@order.status}")
          preset_line_items_for_display(@order)
          format.html { render '/ticket_orders/edit' }
        end
      end
    end
  end

  def find_order
    @order = TicketOrder.find(params[:id])
  end

  def redirect_to_proper_action
    flash.keep
    if @order.editable?
      if params[:action] != 'edit'
        redirect_to(edit_ticket_order_path(@order))
      end
    else
      if params[:action] != 'show'
        redirect_to(ticket_order_path(@order))
      end
    end
  end

  private
  def ticket_order_params
    params.require(:ticket_order).permit(*ticket_order_common_params)
  end
end
