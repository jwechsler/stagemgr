
class OrdersController < ApplicationController

  append_before_filter :find_parents
  append_before_filter :find_order, :only => [:show, :edit, :update, :destroy]
  append_before_filter :redirect_to_proper_action, :only => [:edit, :show]
  
  def new
    @order = @performance.orders.build(:status=>Order::WEB)
    @order.status = Order::NEW
    @order.address = Address.new
    @order.credit_card_payments.build
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
    @order = Order.new(params[:order])
    @credit_card_payment = @order.credit_card_payments.first
    #and clear them out so save works
    @order.credit_card_payments = []
    @order.status = Order::NEW
    begin
      Order.transaction do
        @order.save!
        @order.update_special_offer_line_items_from_code!
        @order.payment_type = Order::CREDIT_CARD
        @credit_card_payment.note=@order.description(@order.ticket_line_items)
        @order.credit_card_payments << @credit_card_payment
        @order.process!
      end
      respond_to do |format|
        flash[:notice] = "Your order has been created"
        format.html { redirect_to(edit_production_performance_order_path(@order.performance.production, @order.performance, @order)) }
        format.xml  { render :xml => @order, :status => :created, :location => @order }
      end
    rescue StandardError => e
        @order.status = Order::NEW
        case e
        when InvalidCreditCard
          flash.now[:notice] = "The credit card you entered was invalid. Reason: #{e.message}"
        when CannotProcessPayment
          flash.now[:notice] = "There was an error while processing your credit card. #{e.message}"
        when ActiveRecord::RecordInvalid
          flash.now[:notice] = "There was an error creating the order. #{e.message}"
        else
          flash.now[:notice] = "There was an error creating the order. #{e.message}"
        end
        render :new
    end
  end

  def update
    @order = Order.find(params[:id])
    @order.attributes = params[:order]
    if @order.status == Order::NEW
      begin
        @credit_card_payment = @order.credit_card_payments.first
        #and clear them out so save works
        @order.credit_card_payments = []
        Order.transaction do
          @order.save!
          @order.update_special_offer_line_items_from_code!
          @order.payment_type = Order::CREDIT_CARD
          @order.credit_card_payments << @credit_card_payment
          @order.process!
        end
      rescue StandardError => e
        @order.status = Order::NEW
        case e
        when InvalidCreditCard
          flash.now[:notice] = "The credit card you entered was invalid. Reason: #{e.message}"
        when CannotProcessPayment
          flash.now[:notice] = "There was an error while processing your credit card. #{e.message}"
        when ActiveRecord::RecordInvalid
          flash.now[:notice] = "There was an error creating the order. #{e.message}"
        else
          flash.now[:notice] = "There was an error creating the order. #{e.message}"
        end
        render :new
        return
      end
    end
    respond_to do |format|
      if @order.save
        if @order.errors.empty? 
          flash[:notice] = "Your order was successfully updated"
        else
          flash[:notice] = @order.errors.full_messages.join('<br/>')
        end
        format.html { redirect_to(edit_production_performance_order_path(@order.performance.production, @order.performance, @order)) }
        format.xml  { head :ok }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @order.errors, :status => :unprocessable_entity }
      end
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
