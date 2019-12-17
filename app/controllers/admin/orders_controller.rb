class Admin::OrdersController < Admin::ApplicationController
  authorize_resource

  include OrdersHelper
  before_action :find_order, :except=>[:index, :new, :create, :update, :fulfill_selected, :autocomplete_service_item_templates_name ]
  before_action :redirect_edits_to_proper_action, :only => [:show,:edit]


  VALID_SEARCH_COLUMNS = [
      'orders.id',
      'display_code',
      'addresses.last_name',
      'addresses.first_name',
      'orders.status'
  ]

  def index
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
    ids = params[:ids]
    orders = Order.where(id:params[:ids])
    logger.debug("Fulfill #{ids.to_s}")
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
    process_order(@order,Order::FULFILLED)
    show
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

  def update_notes
    @order=Order.find(params[:id])
    update_order_notes_from_params(@order, params)
    if @order.save
      flash[:notice] = 'Note updated.'
    end
    redirect_to action:'show', id:@order.id
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
    if @order.cancel!
      redirect_to :action=>"index", :controller=>"admin/orders"
    else
      flash[:error]= @order.errors.full_messages.to_sentence
      redirect_to action:'edit', id:@order.id
    end
  end

  protected

  # for non-editable orders, redirect to 'show' when edit requested
  def redirect_edits_to_proper_action
    if @order.editable? && params[:action].eql?('show') then
      flash.keep
      redirect_to action:'edit', id:@order.id
    elsif !@order.editable? && params[:action].eql?('edit') then
      flash.keep
      redirect_to action:'show', id:@order.id
    end
  end

  # after setting up the record, run the processing based on commit.
  # If no :commit value, and order status has not changed, then just save
  #
  # The new status is determiend by params[:commit], which maps to a status
  # template_by_order_status is called to determine which template to display post-processing
  #
  # @order [Order] order to process
  def create_or_update(order, commit_action=nil)
    new_state = convert_button_label_to_state(params[:commit])
    if new_state.blank? then
      simple_save(order)
    else
      process_order(order,new_state) # Either way the process goes, we pick the display by current status
      respond_to do |format|
        format.html { render template_by_order_status(order, commit_action) }
      end
    end
  end

  # render the template refered to by template_by_order_status for the order
  #
  # @order [Order] order to evaluate
  def render_by_status(order, commit_action = nil)
    respond_to do |format|
      format.html { render template_by_order_status(order, commit_action) }
    end
  end

  # attempts a save, then displays the allowed edit or show page
  def simple_save(order)
    order.save
    render_by_status(order)
  end

  # override if there are more states to determine (like confirmation pages)
  def template_by_order_status(order, commit_action = nil)
    if order.editable?
      'edit'
    else
      'show'
    end
  end

  private

  def filter_by_allowed
    @order = Order.accessible_by(current_ability).find(params[:id])
  end

  def find_order
    @order = Order.find(params[:id]) unless params[:id].blank?
  end

end
