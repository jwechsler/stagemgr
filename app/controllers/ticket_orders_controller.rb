class TicketOrdersController < ApplicationController
  layout 'ext_site_wrapper'
  include OrdersHelper
  include TicketOrdersHelper

  append_before_filter :find_order, :only => [:show, :edit, :update, :destroy, :confirm]
  append_before_filter :redirect_to_proper_action, :only => [:edit, :show]

  respond_to :html

  def edit
    @ticket_order = TicketOrder.find(params[:id].to_i)
    preset_line_items_for_display(@ticket_order)

  end

  def create
    @ticket_order = TicketOrder.new(ticket_order_params)
    @ticket_order.ip_address = request.remote_ip
    update_or_create
  end

  def update
    @ticket_order = TicketOrder.find(params[:id].to_i)
    @ticket_order.update_attributes(ticket_order_params)
    @ticket_order.ip_address = request.remote_ip
    # @ticket_order_for_to_s = @ticket_order.performance.production.name + ' on ' + @ticket_order.performance.performance_date.to_formatted_s(:long_ordinal) +
    #      ' at ' + @ticket_order.performance.performance_time.to_formatted_s(:hour_min)
    update_or_create
  end

  def confirm
    @ticket_order = TicketOrder.find(params[:id].to_i)
  end

#  def donate
#    @ticket_order = TicketOrder.new(ticket_order_params)
#  end

  private
  def update_or_create
    respond_to do |format|
      if !params[:commit].blank? && validate_web_order(@ticket_order) && process_order(@ticket_order, convert_button_label_to_state(params[:commit]))
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
          format.html { render 'edit' }
        end
      end
    end
  end

  def find_order
    @ticket_order = TicketOrder.find(params[:id])
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
