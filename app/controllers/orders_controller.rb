class OrdersController < ApplicationController
  append_before_filter :find_parents
  append_before_filter :find_order, :only => [:show, :edit, :update, :destroy]
  append_before_filter :redirect_to_proper_action, :only => [:edit, :show]
  
  def new
    @order = @performance.orders.build(:status=>Order::WEB)
    @available_ticket_classes = @performance.ticket_classes.select{|tc|tc.web_visible}
    @available_ticket_classes.each{|tc|@order.line_items.build(:ticket_class=>tc)}

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
    @order.status = Order::PROCESSING

    respond_to do |format|
      if @order.save 
        @notice = "Thanks!  Your ticket reservation was been made and your credit card has been charged.  We will see you at the show on #{@order.performance.performance_date.to_formatted_s(:show_date)} at #{@order.performance.performance_time.to_formatted_s(:show_time)}.
        Your tickets will be available for pickup at our box office at 1229 W Belmont one hour before showtime and seating is general admission. 
        If you have any questions, please don't hesitate to call us at 773-975-8150 or email us at boxoffice@theaterwit.org.  Thanks for your support and we'll see you at the theatre.  Enjoy the show!"
        flash[:notice] = @notice
        format.html { redirect_to(edit_production_performance_order_path(@order.performance.production, @order.performance, @order)) }
        format.xml  { render :xml => @order, :status => :created, :location => @order }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @order.errors, :status => :unprocessable_entity }
      end
    end
  end

  def update
    @order = Order.find(params[:id])

    respond_to do |format|
      if @order.update_attributes(params[:order])
        flash[:notice] = 'Order was successfully updated.'
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
