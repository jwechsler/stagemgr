class Admin::ExchangeTicketOrdersController < Admin::ApplicationController
  authorize_resource class: TicketOrder
  # Outside create's rescue so CanCan::AccessDenied reaches the rescue_from handler.
  before_action :authorize_refund, only: :create
  before_action :ensure_exchangeable

  include OrdersHelper
  include TicketOrdersHelper

  REFUND_PARAM = :exchange_and_refund
  EXCHANGE_FAILED = 'There was a problem with the exchange.'.freeze
  REFUND_FAILED = 'Refund could not be processed:'.freeze
  REFUND_NOT_NEEDED = 'Nothing to refund: the new order costs the same as the original, so no refund was issued.'.freeze

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

    preset_exchange_payment_type
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
    flash[:info] = REFUND_NOT_NEEDED if refund_requested? && @exchange_order.refund_not_needed?
    redirect_to admin_ticket_order_path(@exchange_order)
  rescue ExchangeRefundable::ExchangeNotPossible => e
    fail_exchange(e.message, e)
  rescue CannotProcessPayment, ExchangeRefundable::RefundNotPossible => e
    fail_exchange("#{REFUND_FAILED} #{e.message}", e)
  rescue StandardError => e
    fail_exchange("#{EXCHANGE_FAILED} #{e.message}", e)
  end

  private

  # The payment types are the ones the new order's performance allows:
  # TicketOrder#valid_payment_types_for, which drops the performance's
  # restricted types (the same rule the PROCESSED validation enforces). The
  # new order starts on the original's performance; if staff move it, that
  # validation checks the performance they chose. The original's type is
  # preselected when it is allowed; staff may pick any other allowed type.
  def preset_exchange_payment_type
    @allowed_payment_types = TicketOrder.new(performance: @original_order.performance)
                                        .valid_payment_types_for(current_user)
    return unless @allowed_payment_types.map(&:id).include?(@original_order.payment_type_id)

    @exchange_order.payment_type_id = @original_order.payment_type_id
  end

  # The show page hides Exchange for these orders; refuse a direct request
  # too, e.g. from a page left open while the order was refunded or exchanged.
  # The exchange itself re-checks under a row lock (lock_exchange_source!).
  def ensure_exchangeable
    original = TicketOrder.find(params[:ticket_order_id])
    message = if !original.sold_status?
                "Order ##{original.id} is #{original.status} and can no longer be exchanged."
              elsif original.paid_with_pass_and_currency?
                TicketOrderMergeable::MIXED_PAYMENT_NOT_EXCHANGEABLE
              end
    return if message.nil?

    flash[:error] = message
    redirect_to admin_ticket_order_path(original)
  end

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
