class Admin::OrdersController < Admin::ApplicationController
  append_before_filter :find_order, :only => [:show, :edit, :update, :destroy]
  append_before_filter :redirect_to_proper_action, :only => [:edit, :show]

  def autocomplete_production_code
    find_options = {
      :conditions => [ "LOWER(production_code) LIKE ?", '%'+params[:q].to_s.downcase + '%' ],
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
      :conditions => [ "LOWER(performance_code) LIKE ?", '%'+params[:q].to_s.downcase + '%' ],
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
      :conditions => [ "LOWER(class_code) LIKE ?", '%'+params[:q].to_s.downcase + '%' ],
      :order => "class_code ASC",
      :limit => 10
      }
    ticket_classes = performance.production.ticket_classes.scoped(find_options)
    render :inline => ticket_classes.map{|ticket_class| "#{ticket_class.class_code}|#{ticket_class.to_s} (#{ticket_class.number_left(performance)} Tickets Left)|#{ticket_class.ticket_type}|#{ticket_class.ticket_price}"}.join("\n")
  end
  
  def index
    pagination_state = update_pagination_state_with_params!(Order,Performance,Production)
    @options_hash = will_paginate_options_from_pagination_state(pagination_state)
    respond_to do |format|
      format.html # index.html.erb
      format.xml do
        @options_hash.merge!(options_from_search(Order,Performance,Production))
        @options_hash.merge!(:include=>{:performance=>:production})
        @orders = Order.paginate :all, @options_hash
        @order_count = Order.count
        render :partial => 'admin_orders_index_grid_data.xml.builder', :layout => false
      end
    end
  end
  
  def show
  end

  def new
    @order = Order.new
    @order.line_items.build

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @order }
    end
  end
  
  def edit
  end
  
  def create
    @order = Order.new(params[:order])
    respond_to do |format|
      if update_order_status_from_params_and_save(@order, params)
        flash[:notice] = 'Order was successfully created.'
        format.html { redirect_to(edit_admin_order_path(@order)) }
        format.xml  { render :xml => @order, :status => :created, :location => @order }
      else
        format.html { render :action => "new", :controller=>'admin/orders' }
        format.xml  { render :xml => @order.errors, :status => :unprocessable_entity }
      end
    end
  end

  def update
    @order.attributes=params[:order]
    respond_to do |format|
      if update_order_status_from_params_and_save(@order, params)
        flash[:notice] = 'Order was successfully saved.'
        format.html { redirect_to(edit_admin_order_path(@order)) }
        format.xml  { render :xml => @order, :status => :created, :location => @order }
      else
        format.html { render :action => "new", :controller=>'admin/orders' }
        format.xml  { render :xml => @order.errors, :status => :unprocessable_entity }
      end
    end
  end
  
  def cancel
  end
  
  def refund
  end
  
  private
  
  def update_order_status_from_params_and_save(order,params)
    old_status = order.status
    order.status = Order::PROCESSED if params[:commit]=='Manually Processed'
    order.status = Order::PROCESSING if params[:commit]=='Process Online'
    order.status = Order::HELD if params[:commit]=='Hold'
    success = order.save
    unless success
      order.status = old_status
    end
    success
  end
  
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
  
end
