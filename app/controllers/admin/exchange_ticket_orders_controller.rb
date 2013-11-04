class Admin::ExchangeTicketOrdersController < Admin::ApplicationController
  filter_access_to :all
  include OrdersHelper

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
    TicketOrder.transaction do
      begin


        @original_order = TicketOrder.find(params[:ticket_order_id])
        @exchange_order = TicketOrder.new(params[:ticket_order])
        @exchange_order.special_offer_code = params[:ticket_order][:special_offer_code]
        @exchange_order.exchange_and_process_from! @original_order
        respond_to do |format|
          flash[:notice] = 'Order was successfully exchanged.'
          format.html { redirect_to(edit_admin_ticket_order_path(@exchange_order.id)) }
          format.xml { render :xml => @exchange_order, :status => :created, :location => @exchange_order }
        end
      rescue StandardError => e
        respond_to do |format|
          Rails.logger.error("There was a problem with the exchange. #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
          flash[:error] = "There was a problem with the exchange. #{e.message}"
          format.html { render 'new' }
        end
      end

    end

  end
end
