class Admin::RefundOrdersController < Admin::ApplicationController
  def new
    authorize! :refund, Order
    @original_order = Order.find(params[:order_id])
    @refund_order = Order.new
    @refund_order.payments.build

    respond_to do |format|
      format.html # new.html.erb
    end
  end

  def create
    authorize! :refund, Order
    @original_order = Order.find(params[:order_id])
    @original_order.notes = params[:order][:notes] unless params[:order].nil?
    begin
      @original_order.refund!
      flash[:notice] = 'Order was successfully refunded.'
    rescue CannotProcessPayment => e
      flash[:error] = "Refund failed: #{e.message}"
    end
    respond_to do |format|
      format.html { redirect_to(edit_admin_order_path(@original_order.id)) }
    end
  end
end
