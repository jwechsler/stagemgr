class MembershipOfferOrdersController < ApplicationController
  include MembershipOrdersHelper
  def new
    @order = build_membership_order(params[:membership_offer_id].to_i)
    if @order.membership_offer.nil? || !@order.membership_offer.on_sale_to_public?
      render '/general/unavailable', layout: $SERVER_CONFIG['ext_site_wrapper']
      return
    end
    render '/membership_orders/edit', layout: $SERVER_CONFIG['ext_site_wrapper']
   end



end