
class OrdersController < ApplicationController
  include OrdersHelper

  append_before_filter :find_parents
  append_before_filter :find_order, :only => [:show, :edit, :update, :destroy]
  append_before_filter :redirect_to_proper_action, :only => [:edit, :show]
  
  def new
    @order = @performance.orders.build(:status=>Order::WEB)
    @order.status = Order::NEW
    @order.address = Address.new
    @available_ticket_classes.each{|tc|@order.ticket_line_items.build(:ticket_class=>tc)}

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @order }
    end
  end

  def edit
    @order = Order.find(params[:id])
    render :action=>'new'
  end

  def create
    old_status = Order::NEW
    @order = Order.new(params[:order])
    begin
      @order.save!
      old_status = @order.status
      Order.transaction do
        @order.transition_to!(convert_button_label_to_state(params[:commit]))
        @order.transition_to!(Order::PROCESSED) if @order.status == Order::PROCESSING
      end
      respond_to do |format|
        flash[:notice] = "Your ticket reservation was been made"
        format.html { redirect_to(edit_production_performance_order_path(@order.performance.production, @order.performance, @order)) }
        format.xml  { render :xml => @order, :status => :created, :location => @order }
      end
    rescue StandardError => e
      @order.status = old_status
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
      render :action=>'new'
    end
  end

  def update
    @order = Order.find(params[:id])
    old_status = @order.status
    @order.attributes = params[:order]
    begin
      Order.transaction do
        @order.transition_to!(convert_button_label_to_state(params[:commit]))
        @order.transition_to!(Order::PROCESSED) if @order.status == Order::PROCESSING
      end
      respond_to do |format|
        flash.now[:notice] = "Your ticket reservation was been made"
        render :action=>'new'
      end
    rescue StandardError => e
      @order.status = old_status
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
      #render :action=>'new'
    end
  end
  
  def show
    @order = Order.find(params[:id])
  end
  
  private
  def find_parents
    @production = Production.find(params[:production_id])
    @performance = @production.performances.find(params[:performance_id])
    @available_ticket_classes = @performance.ticket_class_allocations.select{|tca|tca.available}.map{|tca|tca.ticket_class}.select{|tc|tc.web_visible}
  end
  
  def find_order
    @order = Order.find(params[:id])
  end

  def redirect_to_proper_action
    if @order.editable?
      if params[:action] != 'edit'
        redirect_to(edit_production_performance_order_path(@order.performance.production, @order.performance, @order))
      end
    else
      if params[:action] != 'show'
        redirect_to(production_performance_order_path(@order.performance.production, @order.performance, @order))
      end
    end
  end
end
