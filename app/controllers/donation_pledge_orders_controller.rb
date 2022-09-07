class DonationPledgeOrdersController < ApplicationController
  layout 'ext_site_wrapper'
  include OrdersHelper
  include DonationOrdersHelper
  before_action :find_order, :only => [:show, :edit, :update, :destroy]
  before_action :redirect_to_proper_action, :only => [:edit, :show]
  before_action :set_donation_levels

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
    @order.donation_line_items.build(:amount=>0)
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
    @order = DonationPledgeOrder.new(donation_pledge_order_params)
    @order.donation_line_items.each { |dli|
      if dli.amount.blank? || dli.amount == 0
        dli.amount = dli.donation_level
        dli.save
      end
    }
    @order.ip_address = request.remote_ip
    create_or_update
  end

  def update
    @order.update_attributes(donation_pledge_order_params)
    @order.ip_address = request.remote_ip
    validate_web_order(@order)
    create_or_update
  end

  def confirm
  end

  protected
  def create_or_update
    respond_to do |format|
      if validate_web_order(@order) && process_order(@order, Order::PROCESSED)
        format.html { render '/donation_pledge_orders/show' }
      else
        format.html { render '/donation_pledge_orders/edit' }
      end
    end
  end


  private
  def find_order
    @order = DonationPledgeOrder.find(params[:id])
  end

  def redirect_to_proper_action
    if @order.editable?
      if params[:action] != 'edit'
        flash.keep
        redirect_to(edit_donation_pledge_order_path(@order))
      end
    else
      if params[:action] != 'show'
        flash.keep
        redirect_to(donation_pledge_order_path(@order))
      end
    end
  end

  def donation_pledge_order_params
    params.require(:donation_pledge_order).permit(*donation_order_common_params)
  end

end
