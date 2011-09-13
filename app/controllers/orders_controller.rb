
class OrdersController < ApplicationController
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
    old_status = Order::NEW
    @order = Order.new(params[:order])
    @order.ip_address = request.remote_ip
    process_order(@order,:edit_order_path)
  end

  def update
    @order.attributes=params[:order]
    @order.ip_address = request.remote_ip
    process_order(@order,:edit_order_path)
  end
  
  def confirm
  end

  def donate

  end
  
  private
  def find_order
    @order = Order.find(params[:id])
  end

  def redirect_to_proper_action
    if @order.editable?
      if params[:action] != 'edit'
        redirect_to(edit_order_path(@order))
      end
    else
      if params[:action] != 'show'
        redirect_to(order_path(@order))
      end
    end
  end
end
