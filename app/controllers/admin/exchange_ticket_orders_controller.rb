class Admin::ExchangeTicketOrdersController < Admin::ApplicationController
  authorize_resource class: TicketOrder

  include OrdersHelper
  include TicketOrdersHelper

  def new
    @original_order = TicketOrder.find(params[:ticket_order_id])
    @exchange_order = TicketOrder.new
    @exchange_order.ticket_line_items.build
    @exchange_order.status = Order::NEW

    @allowed_payment_types = @original_order.payment_type.allowed_payment_types_for_exchange(current_user)
    respond_to do |format|
      format.html # new.html.erb
      format.xml { render :xml => @exchange_order }
    end
  end

  def create
    error = nil
    begin
      @original_order = TicketOrder.find(params[:ticket_order_id])
      @exchange_order = TicketOrder.new(ticket_order_params)
      @exchange_order.regularize_credit_card_expiration
      @exchange_order.special_offer_code = params[:ticket_order][:special_offer_code]
      @exchange_order.exchange_and_process_from! @original_order
      respond_to do |format|
        flash[:notice] = 'Order was successfully exchanged.'
        format.html { redirect_to(edit_admin_ticket_order_path(@exchange_order.id)) }
        format.xml { render :xml => @exchange_order, :status => :created, :location => @exchange_order }
      end
    rescue Exception => e
      Rails.logger.error("There was a problem with the exchange. #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      flash[:error] = "There was a problem with the exchange. #{e.message}"
      redirect_to new_admin_ticket_order_exchange_ticket_order_path(@original_order.id)
    end
  end

  private
  def ticket_order_params
    params.require(:ticket_order).permit(*common_params, *common_ticket_order_params)
  end
end
