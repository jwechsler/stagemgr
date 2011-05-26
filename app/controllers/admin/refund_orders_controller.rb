class Admin::RefundOrdersController < Admin::ApplicationController
  filter_access_to :all

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
    @original_order.notes = params[:order][:notes]
    @original_order.refund!(params[:order].key?(:credit_card_payments_attributes) ? params[:order][:credit_card_payments_attributes]["0"][:card_number] : nil)

    respond_to do |format|
      flash[:notice] = 'Order was successfully refunded.'
      format.html { redirect_to(edit_admin_order_path(@original_order.id)) }
    end

  end
end
