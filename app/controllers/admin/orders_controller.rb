class Admin::OrdersController < Admin::ApplicationController
  include OrdersHelper
  append_before_filter :find_order, :only => [:show, :edit, :update, :destroy, :refund, :cancel]
  append_before_filter :redirect_to_proper_action, :only => [:edit, :show]

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
    pagination_state = update_pagination_state_with_params!(Order,Performance,Production)
    @options_hash = {:conditions=>['productions.status <> ? and performances.status <> ?', 'Inactive', 'Inactive']}
    @options_hash.merge!(will_paginate_options_from_pagination_state(pagination_state))
    respond_to do |format|
      format.html # index.html.erb
      format.xml do
        @options_hash.merge!(options_from_search(Order,Performance,Production))
        @options_hash.merge!(:include=>{:performance=>:production})
        @orders = Order.paginate(:all, @options_hash)
        @order_count = Order.count
        render :partial => 'admin_orders_index_grid_data.xml.builder', :layout => false
      end
    end
  end
  
  def show
  end

  def new
    @order = Order.new
    @order.address = Address.new
    @order.ticket_line_items.build
    @order.status = Order::NEW
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @order }
    end
  end
  
  def edit
  end
  
  def create
    old_status = Order::NEW
    @order = Order.new(params[:order])
    process_order
  end

  def update
    @order.attributes=params[:order]
    process_order
  end
  
  def refund
    @order.refund!
    redirect_to admin_order_path(@order)
  end
  
  def cancel
    @order.cancel!
    redirect_to '/admin/orders'
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
  def process_order
    begin
      @order.save!
      old_status = @order.status
      Order.transaction do
        @order.transition_to!(convert_button_label_to_state(params[:commit]))
        @order.transition_to!(Order::PROCESSED) if @order.status == Order::PROCESSING
      end
    
      respond_to do |format|
        flash[:notice] = "Order was successfully saved and is now #{@order.status_display}"
        format.html { redirect_to(edit_admin_order_path(@order.id)) }
        format.xml  { render :xml => @order, :status => :created, :location => @order }
      end
    rescue StandardError => e
      @order.status = old_status
      respond_to do |format|
        case e
        when InvalidCreditCard
          flash.now[:notice] = "The credit card you entered was invalid. Reason: #{e.message}"
        when CannotProcessPayment
          flash.now[:notice] = "There was an error while processing your credit card. #{e.message}"
        when ActiveRecord::RecordInvalid
          flash.now[:notice] = "There was an error creating the order. #{e.message}"
        else
          flash.now[:notice] = "There was an error creating the order. #{e.message}"
          logger.error "There was an error creating the order. #{e.message} #{e.backtrace}"
        end
        
        format.html { render :new }
      end
    end
    
  end
  
end
