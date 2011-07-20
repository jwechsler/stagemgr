class MembershipOfferOrdersController < ApplicationController

  def new
     @order = MembershipOrder.new
     @order.status = Order::NEW
     @order.address = Address.new
     membership_offer = MembershipOffer.where(:id => params[:membership_offer_id])
     if membership_offer.blank?
       render '/orders/not_available', :layout=>'ext_site_wrapper'
       return
     end
     @order.membership_line_items.build(:membership_offer_id=>params[:membership_offer_id])

     render '/membership_orders/edit', :layout=>'ext_site_wrapper'
   end


end