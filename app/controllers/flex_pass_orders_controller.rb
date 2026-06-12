class FlexPassOrdersController < ApplicationController
  layout $SERVER_CONFIG['ext_site_wrapper']
  include OrdersHelper
  include FlexPassOrdersHelper

  before_action :find_order, only: %i[show edit update destroy]
  before_action :redirect_to_proper_action, only: %i[edit show]

  respond_to :html, :xml, :json

  def show; end
  def show; end
  def new; end

  def confirm; end

  def edit; end

  def create
    @order = FlexPassOrder.new(flex_pass_order_params)
    @order.ip_address = request.remote_ip
    @order.save
    create_or_update
  end

  def update
    @order.update(flex_pass_order_params)
    @order.ip_address = request.remote_ip
    create_or_update
  end

  def confirm; end

  private

  def create_or_update
    respond_to do |format|
      if validate_web_order(@order) && process_order(@order, Order::PROCESSED)
        format.html { render '/flex_pass_orders/show' }
      else
        format.html { redirect_to @order }
      end
    end
  end

  def flex_pass_order_params
    params.require(:flex_pass_order).permit(*common_flex_pass_order_params)
  end

  def find_order
    @order = FlexPassOrder.find(params[:id])
  end

  def redirect_to_proper_action
    if @order.editable?
      redirect_to(edit_flex_pass_order_path(@order)) if params[:action] != 'edit'
    elsif params[:action] != 'show'
      redirect_to(flex_pass_order_path(@order))
    end
  end
end
