class Admin::RefundOrdersController < Admin::ApplicationController
  def new
    @original_order = Order.find(params[:order_id])
    @refund_order = Order.new
    @refund_order.credit_card_payments.build
    

    respond_to do |format|
      format.html # new.html.erb
    end
  end
  
  def create
    @original_order = Order.find(params[:order_id])
    @refund_order = Order.new(params[:order])
    @original_order.payments[0].card_number = @refund_order.credit_card_payments.first.card_number
    @original_order.payments[0].card_verification_number = @refund_order.credit_card_payments.first.card_verification_number
    @original_order.refund!

    respond_to do |format|
      flash[:notice] = 'Order was successfully refunded.'
      format.html { redirect_to(edit_admin_order_path(@original_order.id)) }
    end
    
  end
end
