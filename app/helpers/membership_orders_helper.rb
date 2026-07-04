module MembershipOrdersHelper
  def common_membership_order_params
    [:membership_offer_id, :special_request, :gift, :recipient_name, :recipient_email, :gift_date,
     { membership_line_item_attributes: %i[id membership_offer_id] }] << common_params
  end

  def build_membership_order(offer_id, order = nil)
    if order.nil?
      order = MembershipOrder.new
      order.status = Order::NEW
      order.address = Address.new
      order.build_membership_line_item
    end
    begin
      membership_offer = MembershipOffer.find(offer_id)
    rescue ActiveRecord::RecordNotFound
    end
    order.membership_line_item.membership_offer = membership_offer
    order
  end

  private

  def membership_order_params
    params.require(:membership_order).permit(*common_memberhsip_order_params)
  end
end
