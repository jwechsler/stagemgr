class TicketOrdersController < ApplicationController
  layout 'ext_site_wrapper'
  include OrdersHelper

  append_before_filter :find_order, :only => [:show, :edit, :update, :destroy, :confirm]
  append_before_filter :redirect_to_proper_action, :only => [:edit, :show]

  respond_to :html, :xml, :json

  def edit;
    i = 1
  end

  def show

  end

  def create
    @order = TicketOrder.new(params[:ticket_order])
    @order.ip_address = request.remote_ip
    process_order(@order,:confirm_ticket_order_path) if validate_web_order(@order)
  end

  def update
    @order.attributes=params[:ticket_order]
    @order.ip_address = request.remote_ip
    @order.preset_line_items
    unless @order.special_offer_line_items.empty?
        @order.special_offer_line_items.each {|so|
          so.destroy
          @order.special_offer_line_items.delete(so)
        }
      @order.special_offer_line_items.delete
    end
      # @order.donation_line_items.build(:donation_amount=>0)
    @order_for_to_s = @order.performance.production.name + ' on ' + @order.performance.performance_date.to_formatted_s(:long_ordinal) +
          ' at ' + @order.performance.performance_time.to_formatted_s(:hour_min)
    process_order(@order,:edit_ticket_order_path) if validate_web_order(@order)
  end

  def confirm
    @order = @ticket_order

  end

  def donate
    @order = @ticket_order

  end

  private
  def find_order
    @order = TicketOrder.find(params[:id])
  end

  def redirect_to_proper_action
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
end
