class DonationOrdersController < ApplicationController
  layout $SERVER_CONFIG['ext_site_wrapper']
  include OrdersHelper
  include DonationOrdersHelper

  before_action :find_order, only: %i[show edit update destroy]
  before_action :redirect_to_proper_action, only: %i[edit show]
  before_action :set_donation_levels

  respond_to :html

  def set_donation_levels
    @levels = ActiveSupport::OrderedHash.new
    @levels['Wit Club ($50)'] = 50
    @levels["Artists' Circle ($100)"] = 100
    @levels['Performance Circle ($250)'] = 250
    @levels["Directors' Circle ($500)"] = 500
    @levels["Founders' Circle ($1000)"] = 1000
    @levels['Leadership Circle ($5000)'] = 5000
    @levels['Other Amount (below)'] = -1
    @levels
  end

  def show; end

  def new
    @order = DonationOrder.new
    @order.status = Order::NEW
    @order.address = Address.new
    @order.campaign = params[:campaign] if params.has_key?(:campaign)
    @order.donation_line_items.build(amount: 0)
    # @todo Replace donation levels with user controlled donation level code
    respond_to do |format|
      format.html { render '/donation_orders/edit' }
    end
  end

  def edit; end

  def create
    @order = DonationOrder.new(donation_order_params)
    @order.ip_address = request.remote_ip
    create_or_update
  end

  def update
    @order.update(donation_order_params)
    @order.ip_address = request.remote_ip
    create_or_update
  end

  def create_or_update
    respond_to do |format|
      if validate_web_order(@order) && process_order(@order, Order::PROCESSED)
        format.html { render '/donation_orders/show' }
      else
        format.html { render '/donation_orders/edit' }
      end
    end
  end

  def confirm; end

  def payment_types_for(order, frontend = true)
    types = super
    types.select { |t| t.is_a? CreditCardPaymentType }
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
    elsif params[:action] != 'show'
      flash.keep
      redirect_to(donation_order_path(@order))
    end
  end

  def donation_order_params
    params.require(:donation_order).permit(*donation_order_common_params)
  end
end
