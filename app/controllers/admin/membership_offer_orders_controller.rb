class Admin::MembershipOfferOrdersController < Admin::ApplicationController

  load_and_authorize_resource :membership_order, parent: false

  def new
    @membership_order = MembershipOrder.new
    @membership_order.status = Order::NEW
    @membership_order.address = Address.new
    membership_offer = MembershipOffer.where(:id => params[:membership_offer_id])
    if membership_offer.blank?
      render '/orders/not_available', :layout=>$SERVER_CONFIG['ext_site_wrapper']
      return
    end
    @membership_order.build_membership_line_item(:membership_offer_id=>params[:membership_offer_id])


    render '/admin/membership_orders/edit', :layout=>true
  end

  def create

  end



end