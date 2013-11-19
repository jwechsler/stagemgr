class DonationPledgeOrdersController < ApplicationController
  layout 'ext_site_wrapper'
  include OrdersHelper

  append_before_filter :find_order, :only => [:show, :edit, :update, :destroy]
  append_before_filter :redirect_to_proper_action, :only => [:edit, :show]
  append_before_filter :set_donation_levels

  respond_to :html, :xml, :json

  def set_donation_levels
     @levels = ActiveSupport::OrderedHash.new
     @levels["Ally ($7/month)"] = 7 #84
     @levels["Advocate ($13/month)"] = 13 #156
     @levels["Confidante ($42/month)"] = 42 #504
     @levels["Partner ($84/month)"] = 84 #1008
     @levels
  end

  def new
    @order = DonationPledgeOrder.new
    @order.status = Order::NEW
    @order.address = Address.new
    @order.campaign = params[:campaign] if params.has_key?(:campaign)
    @order.donation_line_items.build(:donation_amount=>0)
    # @todo Replace donation levels with user controlled donation level code
    respond_to do |format|
      format.html { render :edit, :layout=>'ext_site_wrapper' }
    end
  end

  def confirm
  end

  def show
  end

  def edit
  end

  def show
    respond_to do |format|
      format.html { render :show}
    end

  end

  def create
    @order = DonationPledgeOrder.new(params[:donation_pledge_order])
    @order.donation_line_items.each { |dli|
      if dli.donation_amount.blank? || dli.donation_amount == 0
        dli.donation_amount = dli.donation_level
        dli.save
      end
    }
    @order.ip_address = request.remote_ip
    process_order(@order, :edit_donation_pledge_order_path) if validate_web_order(@order)
  end

  def update
    @order.attributes=params[:donation_pledge_order]
    @order.ip_address = request.remote_ip
    validate_web_order(@order)
    process_order(@order, :edit_donation_pledge_order_path)
  end

  def confirm
  end

  private
  def find_order
    @order = DonationPledgeOrder.find(params[:id])
  end

  def redirect_to_proper_action
    if @order.editable?
      if params[:action] != 'edit'
        redirect_to(edit_donation_pledge_order_path(@order))
      end
    else
      if params[:action] != 'show'
        redirect_to(donation_pledge_order_path(@order))
      end
    end
  end
end
