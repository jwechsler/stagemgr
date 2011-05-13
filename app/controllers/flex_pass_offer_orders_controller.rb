class FlexPassOfferOrdersController < ApplicationController
  def new
    @order = Order.new
    @order.status = Order::NEW
    @order.address = Address.new
    flex_pass_offer = FlexPassOffer.where(:id => params[:flex_pass_offer_id], :active => true)
    if flex_pass_offer.blank?
      render '/orders/not_available', :layout=>'none'
      return
    end
    @order.flex_pass_line_items.build(:flex_pass_offer_id=>params[:flex_pass_offer_id])

    @order_for_to_s = flex_pass_offer[0].name
    render '/orders/edit', :layout=>'none'
  end

end