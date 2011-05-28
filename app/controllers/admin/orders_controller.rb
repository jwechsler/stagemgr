class Admin::OrdersController < Admin::ApplicationController

  filter_resource_access :attribute_check => true, :additional_new=>{:create => :new}, :additional_member=>{:refund, :refund}

  include OrdersHelper
  #append_before_filter :find_order, :only => [:show, :edit, :update, :destroy, :refund, :cancel, :fulfill]
  #append_before_filter :filter_by_allowed, :only => [:show, :edit, :update, :destroy, :refund, :cancel, :fulfill]
  append_before_filter :redirect_to_proper_action, :only => [:edit, :show]

  VALID_SEARCH_COLUMNS = [
    'orders.id',
    'productions.production_code',
    'performances.performance_code',
    'addresses.last_name',
    'addresses.first_name',
    'orders.status'
  ]

  def index
    store_search_and_pagination_state unless !session[:existing_box_office_orders_state].nil?
    respond_to do |format|
      format.html # index.html.erb
      format.xml do
        store_search_and_pagination_state
        @options_hash = get_search_conditions_from_params
        @options_hash.merge!(get_pagination_options_from_params)
        @options_hash.merge!(:include=>[{:performance=>:production}, :address])
        @orders = Order.paginate @options_hash
        @total_records = @orders.total_entries
        @total_pages = @total_records/@orders.per_page+1
        render :partial => 'admin_orders_index_grid_data.xml.builder', :layout => false
      end
    end
  end

  def show

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

  def fulfill
    params[:commit] = 'Fulfill'
    process_order(:admin_order_path)
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
  end


  def create
    old_status = Order::NEW
    @order = Order.new(params[:order])
    process_order(:edit_admin_order_path)
  end

  def update
    @order.attributes=params[:order]
    link_order_to_address_of_record
    process_order(:edit_admin_order_path)
  end

  def refund

    @order.refund!
    redirect_to admin_order_path(@order)
  end

  def cancel
    # @order.cancel!
    redirect_to :action=>"index", :controller=>"admin/orders"
  end

  private

  def redirect_to_proper_action
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
    conditions_sql = ['(productions.status <> ? or productions.status is null)', '(performances.status <> ? or performances.status is null)']
    conditions_params = ['Inactive', 'Inactive']
    # Hide orders that we couldn't figure out how to obscure in declarative_authorizations because of paginate block
    # @todo this is probably fixable...

    if !(Authorization.current_user.is_administrator? || Authorization.current_user.is_box_office_user?)
      conditions_sql += ['orders.theater_id is not null and orders.theater_id in (?)']
      conditions_params << Authorization.current_user.theater_ids
    end

    if params['_search']=='true'
      VALID_SEARCH_COLUMNS.each do |column_name|
        if params[column_name] && !params[column_name].empty?
          if column_name.downcase == 'performances.performance_code'
            conditions_sql << "((performance_id is null and 'flexpass' like '%' ? '%') or lower(#{column_name}) like '%' ? '%')"
            conditions_params << params[column_name].downcase << params[column_name].downcase
          else
            conditions_sql << "lower(#{column_name}) like '%' ? '%'"
            conditions_params << params[column_name].downcase
          end
        end
      end
    end
    {:conditions=>([conditions_sql.join(' and ')] + conditions_params)}
  end

  def get_pagination_options_from_params
    sort_column = params[:sidx]
    sort_column = 'orders.id' if sort_column.empty?
    sort_order = params[:sord]
    sort_order 'ASC' if sort_order.empty?
    {:page => params[:page], :order => "#{sort_column} #{sort_order}"}
  end


end
