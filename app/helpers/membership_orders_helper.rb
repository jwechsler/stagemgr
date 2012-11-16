module MembershipOrdersHelper

  def create_membership
    success = false
    begin
      MembershipOrder.transaction do
        @order = MembershipOrder.new(params[:membership_order])
        @order.ip_address = request.remote_ip
        @order.transition_to!(Order::PROCESSING)
        membership_offer = @order.membership_offer
        @order.gift_date = @order.gift_date + 1.year unless (@order.gift_date.nil? || @order.gift_date >= Date.today)
        f_name, m_name, l_name = @order.address.parse_full_name
        @order.credit_card_expiration_year = self.fix_expiration_year(@order.credit_card_expiration_year)
        credit_card = PaymentProcessing.credit_card(@order.credit_card_type,
                                                    f_name,
                                                    l_name,
                                                    @order.credit_card_number,
                                                    @order.credit_card_expiration_month,
                                                    @order.credit_card_expiration_year,
                                                    @order.credit_card_verification_number)
        response = recurring_response(membership_offer, credit_card,
                                      @order.ip_address, @order.id, @order.address.email,
                                      @order.gift? ? @order.gift_date : Date.today)
        success = response.success?
        if success
          profile_id = response.params["profile_id"]
          membership = @order.membership
          membership.profile_id = profile_id
          membership.status = response.params["profile_status"][0..-8]
          membership.save!
          @order.transition_to!(Order::PROCESSED)
        else
          flash[:error] = raw "There was a problem setting up your account for the <strong>#{membership_offer.name}</strong> payment plan. #{response.message}"
        end
      end
    rescue Exception=> e
      success = false

      flash[:error] = e.message
      Rails.logger.error(e.backtrace)
    end
    success
  end

  private
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
