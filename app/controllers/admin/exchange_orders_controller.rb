class Admin::ExchangeOrdersController < Admin::ApplicationController
 filter_access_to :all

  def new
    @original_order = Order.find(params[:order_id])
    @exchange_order = TicketOrder.new
    @exchange_order.ticket_line_items.build
    @exchange_order.status = Order::NEW
    @allowed_payment_types =  [Order::FLEX_PASS] if @original_order.paid_with_pass?

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @exchange_order }
    end  
  end
  
  def create
    @original_order = TicketOrder.find(params[:order_id])
    @exchange_order = TicketOrder.new(params[:order])
    @exchange_order.special_offer_code = params[:order][:special_offer_code]
    @exchange_order.exchange_and_process_from! @original_order
    respond_to do |format|
      flash[:notice] = 'Order was successfully exchanged.'
      format.html { redirect_to(edit_admin_order_path(@exchange_order.id)) }
      format.xml  { render :xml => @exchange_order, :status => :created, :location => @exchange_order }
    end
    
  end
end
