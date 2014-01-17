class DonationOrdersController < ApplicationController
  layout 'ext_site_wrapper'
  include OrdersHelper

  append_before_filter :find_order, :only => [:show, :edit, :update, :destroy]
  append_before_filter :redirect_to_proper_action, :only => [:edit, :show]
  append_before_filter :set_donation_levels

  respond_to :html, :xml, :json

  def set_donation_levels
    @levels = ActiveSupport::OrderedHash.new
    @levels["Friend ($25)"] = 25
    @levels["Ally ($75)"] = 75
    @levels["Advocate ($150)"] = 150
    @levels["Confidante ($500)"] = 500
    @levels["Partner ($1000)"] = 1000
    @levels["Patron ($2500)"] = 2500
    @levels
  end

  def new
    @order = DonationOrder.new
    @order.status = Order::NEW
    @order.address = Address.new
    @order.campaign = params[:campaign] if params.has_key?(:campaign)
    @order.donation_line_items.build(:donation_amount=>0)
    # @todo Replace donation levels with user controlled donation level code
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
        flash.keep
        redirect_to(edit_donation_order_path(@order))
      end
    else
      if params[:action] != 'show'
        flash.keep
        redirect_to(donation_order_path(@order))
      end
    end
  end
end
