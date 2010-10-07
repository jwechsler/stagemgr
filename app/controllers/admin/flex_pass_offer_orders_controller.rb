class Admin::FlexPassOfferOrdersController < Admin::ApplicationController
  def new
    @order = Order.new
    @order.status = Order::NEW
    @order.address = Address.new
    @order.flex_pass_line_items.build(:flex_pass_offer_id=>params[:flex_pass_offer_id])
    render '/admin/orders/edit', :layout=>true
  end
end

