class Admin::ExchangeTicketOrdersController < Admin::ApplicationController
  authorize_resource class: TicketOrder
  # Outside create's rescue so CanCan::AccessDenied reaches the rescue_from handler.
  before_action :authorize_refund, only: :create

  include OrdersHelper
  include TicketOrdersHelper

  REFUND_PARAM = :exchange_and_refund
  EXCHANGE_FAILED = 'There was a problem with the exchange.'.freeze
  REFUND_FAILED = 'Refund could not be processed:'.freeze

  expose :order_production_id, lambda {
    if !@original_order.nil? && !@original_order.performance.nil?
      @original_order.performance.production_id
    elsif !params[:new_production_id].nil?
      params[:new_production_id]
    elsif !params[:production_id].nil?
      params[:production_id]
    else
      ''
    end
  }

  expose :order_production, -> { Production.find(order_production_id) }

  def new
    @original_order = TicketOrder.find(params[:ticket_order_id])
    @original_order.status = Order::EXCHANGING
    @exchange_order = TicketOrder.new
    @exchange_order.create_exchange_service_fees(@original_order)
    @exchange_order.ticket_line_items.build
    @exchange_order.status = Order::NEW

    @allowed_payment_types = @original_order.payment_type.allowed_payment_types_for_exchange(current_user)
    respond_to do |format|
      format.html # new.html.erb
    end
  end

  def create
    @original_order = TicketOrder.find(params[:ticket_order_id])
    @exchange_order = build_exchange_order
    if refund_requested?
      @exchange_order.exchange_and_refund_from!(@original_order)
    else
      @exchange_order.exchange_and_process_from!(@original_order)
    end
    flash[:notice] = 'Order was successfully exchanged.'
    redirect_to admin_ticket_order_path(@exchange_order)
  rescue CannotProcessPayment, ExchangeRefundable::RefundNotPossible => e
    fail_exchange("#{REFUND_FAILED} #{e.message}", e)
  rescue StandardError => e
    fail_exchange("#{EXCHANGE_FAILED} #{e.message}", e)
  end

  private

  def refund_requested?
    params.key?(REFUND_PARAM)
  end

  def authorize_refund
    authorize!(:refund, TicketOrder) if refund_requested?
  end

  def build_exchange_order
    exchange_order = TicketOrder.new(ticket_order_params)
    exchange_order.regularize_credit_card_expiration
    exchange_order.special_offer_code = params[:ticket_order][:special_offer_code]
    exchange_order.uuid = params[:uuid]
    exchange_order
  end

  def fail_exchange(message, error)
    Rails.logger.error("#{message}\n#{error.backtrace.join("\n")}")
    flash[:error] = message
    redirect_to admin_ticket_order_path(params[:ticket_order_id])
  end

  def ticket_order_params
    params.require(:ticket_order).permit(*ticket_order_common_params)
  end
end
