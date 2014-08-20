class Admin::OrdersController < Admin::ApplicationController

  filter_resource_access :attribute_check => true, :additional_new=>{:create => :new}, :additional_member=>{:refund => :refund, :update_notes=>:update_notes}, :additional_collection=>{:fulfill_selected=>:index, :unclaim_selected=>:index}

  include OrdersHelper
  #append_before_filter :find_order, :only => [:show, :edit, :update, :destroy, :refund, :cancel, :fulfill]
  #append_before_filter :filter_by_allowed, :only => [:show, :edit, :update, :destroy, :refund, :cancel, :fulfill]
  append_before_filter :redirect_to_proper_action, :only => [:edit, :show]

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
       # index.html.erb
      # format.xml do
      #   store_search_and_pagination_state
      #   @options_hash = get_search_conditions_from_params
      #   @options_hash.merge!(get_pagination_options_from_params)
      #   @options_hash.merge!(:include=>[{:performance=>:production}, :address, :payments])
      #   @orders = Order.paginate @options_hash
      #   @total_records = @orders.total_entries
      #   @total_pages = @total_records/@orders.per_page+1
      #   render :partial => 'admin_orders_index_grid_data.xml.builder', :layout => false
      # end
      format.json { render json: OrdersDatatable.new(view_context) }
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
    logger.info params[:ids].to_s
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

    end
  end


  def create
    old_status = Order::NEW
    @order = Order.new(params[:order])
    @order = process_order(@order,:edit_admin_order_path)
  end

  def update
    @order.attributes=params[:order]
    @order = process_order(@order,:edit_admin_order_path)
  end

  def update_notes
    @order=Order.find(params[:id])
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
    @order = Order.find(params[:id])
    permission_denied unless (Authorization.current_user.is_administrator? || Authorization.current_user.is_box_office? || Authorization.current_user.theater_ids.include?(@order.theater_id))

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

  def get_search_conditions_from_params
    conditions_sql = Array.new
    conditions_params = Array.new
    # Hide orders that we couldn't figure out how to obscure in declarative_authorizations because of paginate block
    # @todo this is probably fixable...

    if !(Authorization.current_user.is_administrator? || Authorization.current_user.is_box_office_user?)
      conditions_sql += ['orders.theater_id is not null and orders.theater_id in (?)']
      conditions_params << Authorization.current_user.theater_ids
    end

    restrict_to_active = true
    remove_active_restrict_on_columns = ['orders.id', 'addresses.last_name', 'addresses.first_name']

    if params['_search']=='true'
      VALID_SEARCH_COLUMNS.each do |column_name|
        if params[column_name] && !params[column_name].empty?
          restrict_to_active &&= !remove_active_restrict_on_columns.include?(column_name)
          case column_name
            when 'display_code' then
              case params[column_name].downcase
                when 'membership' then
                  conditions_sql << "orders.type = 'MembershipOrder'"
                when 'donation' then
                  conditions_sql << "orders.type = 'DonationOrder'"
                when 'flexpass' then
                  conditions_sql << "orders.type = 'FlexPassOrder'"
                  conditions_sql << "(orders.id in (select order_id from flex_passes where active = 1))" if restrict_to_active
                else
                  conditions_sql << "orders.type = 'TicketOrder' and lower(performances.performance_code) like '%' ? '%'"
                  conditions_params << params[column_name].downcase
              end
            when 'orders.id' then
              conditions_sql << "#{column_name} = ?"
              conditions_params << params[column_name]

            else
              conditions_sql << "lower(#{column_name}) like '%' ? '%'"
              conditions_params << params[column_name].downcase
          end
        end
      end
    end

    if restrict_to_active
      conditions_sql << '(productions.status <> ? or productions.status is null)' << '(performances.status <> ? or performances.status is null)'
      conditions_params << Production::INACTIVE << Performance::INACTIVE
    end

    {:conditions=>([conditions_sql.join(' and ')] + conditions_params)}
  end

  def get_pagination_options_from_params
    sort_column = params[:sidx]
    sort_column = 'orders.id' if sort_column.empty?
    sort_column = "case orders.type when 'TicketOrder' then performances.performance_code when 'Order' then null else orders.type end" if sort_column == 'display_code'
    sort_order = params[:sord]
    sort_order 'DESC' if sort_order.empty?
    {:page => params[:page], :order => "#{sort_column} #{sort_order}"}
  end


end
