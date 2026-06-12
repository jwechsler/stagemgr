class Admin::FlexPassOfferOrdersController < Admin::ApplicationController
  def new
    @flex_pass_order = FlexPassOrder.new
    @flex_pass_order.status = Order::NEW
    @flex_pass_order.address = Address.new
    @flex_pass_order.build_flex_pass_line_item(flex_pass_offer_id: params[:flex_pass_offer_id])
    render '/admin/flex_pass_orders/edit', layout: true
  end
end
