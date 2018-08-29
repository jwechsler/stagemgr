class Admin::OrdersController < Admin::ApplicationController
  load_and_authorize_resource

  include OrdersHelper

  before_action :find_order, :only => [:show, :edit, :update, :destroy, :refund, :cancel, :fulfill]
  before_action :redirect_to_proper_action, :only => [:edit, :show]

  VALID_SEARCH_COLUMNS = [
      'orders.id',
      'display_code',
      'addresses.last_name',
      'addresses.first_name',
      'orders.status'
  ]

  def index
    # store_search_and_pagination_state unless !session[:existing_box_office_orders_state].nil?
    respond_to do |format|
      format.html
      format.json {
        render json: OrdersDatatable.new(params, view_context: view_context, current_user: current_user)
      }
    end
  end

  def show
    flash.keep
    if @order.is_a? MembershipOrder
      redirect_to url_for(:controller=>:membership_orders, :action=>:show, :id=>@order.id)
    elsif @order.is_a? TicketOrder
      redirect_to url_for(:controller=>:ticket_orders, :action=>:show, :id=>@order.id)
    elsif @order.is_a? DonationOrder
      redirect_to url_for(:controller=>:donation_orders, :action=>:show, :id=>@order.id)
    elsif @order.is_a? FlexPassOrder
      redirect_to url_for(:controller=>:flex_pass_orders, :action=>:show, :id=>@order.id)
    end
  end

  def fulfill_selected
    params[:commit] = 'Fulfill'
    orders = Order.find(params[:ids])
    statuses = {}
    orders.each do |order|
      if order.status == 'Processed'
        order.transition_to!(Order::FULFILLED)
        statuses[order.id]={:success=>true}
      else
        statuses[order.id]={:success=>false, :message=>"Only 'Processed' orders can be fulfilled"}
      end
    end
    render :json=>statuses.to_json
  end

  def unclaim_selected
    params[:commit] = 'Unclaimed'
    orders = Order.find(params[:ids])
    logger.info params[:ids].to_s
    statuses = {}
    orders.each do |order|
      if order.status == 'Fulfilled'
        order.transition_to!(Order::UNCLAIMED)
        statuses[order.id]={:success=>true}
      else
        statuses[order.id]={:success=>false, :message=>"Only 'Fulfilled' orders can be unclaimed"}
      end
    end
    render :json=>statuses.to_json
  end

  def fulfill
    params[:commit] = 'Fulfill'
    @order = process_order(@order,:admin_order_path)
  end

  def new
    @order = Order.new
    @order.address = Address.new
    @order.ticket_line_items.build
    @order.status = Order::NEW

    respond_to do |format|
      format.html { render 'edit', :layout=>true }
    end
  end

  def edit
    if @order.is_a? TicketOrder
      flash.keep
      redirect_to(:controller=>:ticket_orders, :action=>:show, :id=>@order.id)
    elsif @order.is_a? FlexPassOrder
      flash.keep
      redirect_to(:controller=>:flex_pass_orders, :action=>:show, :id=>@order.id)
    elsif @order.is_a? DonationOrder
      flash.keep
      redirect_to(:controller=>:donation_orders, :action=>:show, :id=>@order.id)
    end
  end

  def update
    @order.attributes=params[:order]
    @order = process_order(@order,:edit_admin_order_path)
  end

  def update_notes
    @order=Order.find(params[:id])
    @order.hold_under=params[:ticket_order][:hold_under]
    @order.notes=params[:notes]
    if @order.save
      flash[:notice] = 'Note updated.'
    end
    self.redirect_to_proper_action
  end

  def refund
    @order.refund!
    redirect_to admin_order_path(@order)
  end

  def unclaimed
    @order.unclaimed!
    redirect_to admin_order_path(@order)
  end

  def cancel
    raise "Cannot cancel orders with payments" if @order.payments.size > 0
    @order.cancel!
    redirect_to :action=>"index", :controller=>"admin/orders"
  end

  protected

  def redirect_to_proper_action
    flash.keep
    if @order.editable?
      if params[:action] != 'edit'
        redirect_to(edit_admin_order_path(@order))
      end
    else
      if params[:action] != 'show'
        redirect_to(admin_order_path(@order))
      end
    end
  end

  def find_order
    @order = Order.find(params[:id])
  end

  private

  def filter_by_allowed
    @order = Order.accessible_by(current_ability).find(params[:id])
  end

  def store_search_and_pagination_state
    state_to_store = {}
    if params['_search']=='true'
      VALID_SEARCH_COLUMNS.each do |column_name|
        state_to_store[column_name]=params[column_name] if params[column_name] && !params[column_name].empty?
      end
    end
    ['page', 'rows', 'sidx', 'sord'].each do |column_name|
      state_to_store[column_name]=params[column_name] if params[column_name] && !params[column_name].empty?
    end
    session[:existing_box_office_orders_state] = state_to_store
  end



end
