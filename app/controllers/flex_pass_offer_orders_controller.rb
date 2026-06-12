class FlexPassOfferOrdersController < ApplicationController
  def new
    @order = FlexPassOrder.new
    @order.status = Order::NEW
    @order.address = Address.new
    flex_pass_offer = FlexPassOffer.accessible_by(current_ability).find_by(id: params[:flex_pass_offer_id],
                                                                           active: true)
    if flex_pass_offer.nil? || !flex_pass_offer.on_sale_to_public?
      render '/orders/not_available', layout: Rails.configuration.x.server_config['ext_site_wrapper']
      return
    end
    @order.build_flex_pass_line_item(flex_pass_offer_id: params[:flex_pass_offer_id])

    @order_for_to_s = flex_pass_offer.name
    render '/flex_pass_orders/edit', layout: Rails.configuration.x.server_config['ext_site_wrapper']
  end
end
