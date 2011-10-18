class DonationOrdersController < ApplicationController
  layout 'ext_site_wrapper'
  include OrdersHelper

  append_before_filter :find_order, :only => [:show, :edit, :update, :destroy]
  append_before_filter :redirect_to_proper_action, :only => [:edit, :show]

  respond_to :html, :xml, :json

  def new
    @order = DonationOrder.new
    @order.status = Order::NEW
    @order.address = Address.new
    @order.donation_line_items.build(:donation_amount=>0)
    # @todo Replace donation levels with user controlled donation level code
    @levels = ActiveSupport::OrderedHash.new
    @levels["Buddy ($100)"] = 100
    @levels["Fast Friend ($250)"] = 250
    @levels["Comrade ($500)"] = 500
    @levels["Confidante ($1500)"] = 1500
    @levels["Patron ($2500)"] = 2500
    respond_to do |format|
      format.html { render '/donation_orders/edit', :layout=>'ext_site_wrapper' }
    end
  end

  def confirm
  end

  def show
  end

  def edit
  end

  def show;
  end

  def create
    @order = DonationOrder.new(params[:donation_order])
    @order.ip_address = request.remote_ip
    process_order(@order, :edit_donation_order_path) if validate_web_order(@order)
  end

  def update
    @order.attributes=params[:donation_order]
    @order.ip_address = request.remote_ip
    validate_web_order(@order)
    process_order(@order, :edit_donation_order_path)
  end

  def confirm
  end

  private
  def find_order
    @order = DonationOrder.find(params[:id])
  end

  def redirect_to_proper_action
    if @order.editable?
      if params[:action] != 'edit'
        redirect_to(edit_donation_order_path(@order))
      end
    else
      if params[:action] != 'show'
        redirect_to(donation_order_path(@order))
      end
    end
  end
end
