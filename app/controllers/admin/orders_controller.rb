class Admin::OrdersController < Admin::ApplicationController
  include OrdersHelper
  append_before_filter :find_order, :only => [:show, :edit, :update, :destroy, :refund, :cancel, :fulfill]
  append_before_filter :redirect_to_proper_action, :only => [:edit, :show]
  
  VALID_SEARCH_COLUMNS = [ 
    'orders.id', 
    'productions.production_code', 
    'performances.performance_code', 
    'addresses.last_name', 
    'addresses.first_name',
    'orders.status'
  ]

  def autocomplete_production_code
    find_options = {
      :conditions => [ "LOWER(production_code) LIKE ? and status != 'Inactive'", '%'+params[:q].to_s.downcase + '%' ],
      :order => "production_code ASC",
      :limit => 10
      }
      productions = Production.scoped(find_options)
      render :inline => productions.map{|production| "#{production.production_code}|#{production.to_s}"}.join("\n")
  end
  
  def autocomplete_performance_code
    production = Production.find_by_production_code(params[:production_code])
    return [] if production.nil?
    find_options = {
      :conditions => [ "LOWER(performance_code) LIKE ? and status != 'Inactive'", '%'+params[:q].to_s.downcase + '%' ],
      :order => "performance_code ASC",
      :limit => 10
      }
    performances = production.performances.scoped(find_options)
    render :inline => performances.map{|performance| "#{performance.performance_code}|#{performance.to_s}"}.join("\n")
  end
  
  def autocomplete_ticket_class_code
    performance = Performance.find_by_performance_code(params[:performance_code])
    return [] if performance.nil?
    find_options = {
      :conditions => [ "LOWER(class_code) LIKE ? AND id IN (SELECT ticket_class_id from ticket_class_allocations where performance_id = ? and available = 1)", '%'+params[:q].to_s.downcase + '%', performance.id ],
      :order => "class_code ASC",
      :limit => 10
      }
    ticket_classes = performance.production.ticket_classes.scoped(find_options)
    render :inline => ticket_classes.map{|ticket_class| "#{ticket_class.class_code}|#{ticket_class.to_s} (#{ticket_class.number_left(performance)} Tickets Left)|#{ticket_class.ticket_type}|#{ticket_class.ticket_price}"}.join("\n")
  end
  
  def index
    store_search_and_pagination_state unless !session[:existing_box_office_orders_state].nil?
    respond_to do |format|
      format.html # index.html.erb
      format.xml do
        store_search_and_pagination_state
        @options_hash = get_search_conditions_from_params
        @options_hash.merge!(get_pagination_options_from_params)
        @options_hash.merge!(:include=>[{:performance=>:production},:address])
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
    orders.each { |o|
      if o.status == 'Processed'
        o.transition_to!(Order::FULFILLED)
      end
    }
    logger.info params[:ids].to_s
  end
  
  def fulfill
    # @todo smelly code.  Why do I have to do this?
    params[:commit] = 'Fulfill'
    process_order(:admin_order_path)
  end
  
  def new
    @order = Order.new
    @order.address = Address.new
    @order.ticket_line_items.build
    @order.status = Order::NEW
    respond_to do |format|
      format.html{ render 'edit', :layout=>true }
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
  
  def store_search_and_pagination_state
    state_to_store = {}
    if params['_search']=='true'
      VALID_SEARCH_COLUMNS.each do |column_name|
        state_to_store[column_name]=params[column_name] if params[column_name] && !params[column_name].empty?
      end
    end
    ['page','rows','sidx','sord'].each do |column_name|
      state_to_store[column_name]=params[column_name] if params[column_name] && !params[column_name].empty?
    end
    session[:existing_box_office_orders_state] = state_to_store
  end
  
  def get_search_conditions_from_params
    conditions_sql = ['(productions.status <> ? or productions.status is null)', '(performances.status <> ? or performances.status is null)']
    conditions_params = ['Inactive', 'Inactive']
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
    {:conditions=>([conditions_sql.join(' and ')] + conditions_params) }
  end
  
  def get_pagination_options_from_params
    sort_column = params[:sidx]
    sort_column = 'orders.id' if sort_column.empty?
    sort_order = params[:sord]
    sort_order 'ASC' if sort_order.empty?
    {:page => params[:page], :order => "#{sort_column} #{sort_order}"}
  end
  
end
