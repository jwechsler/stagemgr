class Admin::OrdersController < ApplicationController
  append_before_filter :find_order, :only => [:show, :edit, :update, :destroy]
  append_before_filter :redirect_to_proper_action, :only => [:edit, :show]
  autocomplete_for :performance, :performance_code
  
  def index
    @orders = Order.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @orders }
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
    if @order.status == Order::HELD || @order.status.nil?
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
