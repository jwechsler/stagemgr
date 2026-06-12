class OrdersController < ApplicationController
  layout $SERVER_CONFIG['ext_site_wrapper']
  include OrdersHelper

  before_action :find_order, only: %i[show edit update destroy]
  before_action :redirect_to_proper_action, only: %i[edit show]

  respond_to :html, :xml, :json

  private

  def klass
    Object.const_get params[:controller].classify
  end

  def find_order
    @order = Order.find(params[:id])
  end

  def redirect_to_proper_action
    if @order.editable?
      redirect_to(edit_order_path(@order)) if params[:action] != 'edit'
    elsif params[:action] != 'show'
      redirect_to(order_path(@order))
    end
  end
end
