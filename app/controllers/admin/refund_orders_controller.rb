class Admin::RefundOrdersController < Admin::ApplicationController
  def new
    authorize! :refund, Order
    @original_order = Order.find(params[:order_id])
    @refund_order = Order.new
    @refund_order.payments.build
    # The refund plan: what the page shows and Order#refund! will do.
    @refund_blockers = @original_order.refund_blockers
    @exchange_chain = @original_order.exchange_chain
    @refund_tenders = @original_order.refund_tenders
    @refund_reversals = @original_order.refund_reversals

    respond_to do |format|
      format.html # new.html.erb
    end
  end

  def create
    authorize! :refund, Order
    @original_order = Order.find(params[:order_id])
    blockers = @original_order.refund_blockers
    return refuse_refund(blockers) if blockers.any?

    @original_order.notes = params[:order][:notes] unless params[:order].nil?
    begin
      @original_order.refund!
      flash[:notice] = 'Order was successfully refunded.'
    rescue CannotProcessPayment => e
      flash[:error] = "Refund failed: #{e.message}"
    rescue Order::RefundNotAllowed => e
      return refuse_refund([e.message])
    end
    respond_to do |format|
      format.html { redirect_to(edit_admin_order_path(@original_order.id)) }
    end
  end

  private

  # The page offers no refund button in these cases; this refuses a post anyway.
  def refuse_refund(blockers)
    flash[:error] = "Order ##{@original_order.id} can't be refunded: #{blockers.to_sentence}"
    redirect_to(edit_admin_order_path(@original_order.id))
  end
end
