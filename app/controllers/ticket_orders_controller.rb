
class TicketOrdersController < ApplicationController
  layout 'ext_site_wrapper'
  include OrdersHelper

  append_before_filter :find_order, :only => [:show, :edit, :update, :destroy]
  append_before_filter :redirect_to_proper_action, :only => [:edit, :show]

  respond_to :html, :xml, :json

  def edit;
    i = 1
  end

  def show; end

  def create
    @order = TicketOrder.new(params[:ticket_order])
    @order.ip_address = request.remote_ip
    process_order(@order,:edit_ticket_order_path) if validate_web_order(@order)
  end

  def update
    @order.attributes=params[:ticket_order]
    @order.ip_address = request.remote_ip
    validate_web_order(@order)
    process_order(@order,:edit_ticket_order_path)
  end
  
  def confirm
  end

  def donate

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
