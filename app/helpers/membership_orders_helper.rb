module MembershipOrdersHelper

  def common_membership_order_params
    [:membership_offer_id, :special_request, :gift, :recipient_name, :recipient_email, :gift_date, membership_line_item_attributes: [:id, :membership_offer_id] ] << common_params
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
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.debug("*** Could not find offer id #{offer_id}")
    end
    order.membership_line_item.membership_offer = membership_offer
    Rails.logger.debug("*** found #{order.membership_line_item.membership_offer.name}")
    Rails.logger.debug("*** found #{order.membership_offer.name}")

    order
  end

  private

  def membership_order_params
    params.require(:membership_order).permit(*common_memberhsip_order_params)
  end

  def recurring_response(membership_offer, credit_card, ip, order_id, email, start_date = Date.today)
    start_date ||= Date.today
    gateway ||= PaymentProcessing.recurring_gateway

    trial_amt = membership_offer.trial_amount
    trial_amt = (trial_amt*100).to_i unless trial_amt.nil?

    response = gateway.recurring((membership_offer.recurring_cost * 100).to_i, credit_card,
                                   :ip=>ip, :order_id =>order_id, :email=>email,
                                   :description => membership_offer.billing_agreement,
                                   :start_date=>start_date,
                                   :period=>'Month', :frequency=>1, :max_failed_payments=>1,
                                   :auto_bill_outstanding=> true,
                                   :trial_amount => trial_amt,
                                   :trial_frequency=>1,
                                   :trial_period => 'Month',
                                   :trial_cycles => membership_offer.trial_period)
    response
  end

end
