class FlexPassOfferOrdersController < ApplicationController
  def new
    @order = Order.new
    @order.status = Order::NEW
    @order.address = Address.new
    @flex_pass_offer = FlexPassOffer.find(params[:flex_pass_offer_id])
    @order.flex_pass_line_items.build(:flex_pass_offer_id=>@flex_pass_offer.id)
    @order_for_to_s = 'Flex Pass'
    render '/orders/edit', :layout=>false
  end
end