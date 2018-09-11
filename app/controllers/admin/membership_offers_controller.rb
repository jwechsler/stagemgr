class Admin::MembershipOffersController < ApplicationController
  load_and_authorize_resource

  def index
    respond_to do |format|
      format.html
      format.json {
        params.permit!
        render json: MembershipOfferDatatable.new(params, view_context: view_context )
      }
    end
  end

  def show
  end

  def new
    @membership_offer = MembershipOffer.new
  end

  def create
    @membership_offer = MembershipOffer.new(membership_offer_params)
    if @membership_offer.save
      redirect_to [:admin, @membership_offer], :notice => "Successfully created membership offer."
    else
      render :action => 'new'
    end
  end

  def edit
  end

  def update
    if @membership_offer.update_attributes(membership_offer_params)
      redirect_to [:admin, @membership_offer], :success  => "Successfully updated membership offer."
    else
      render :action => 'edit'
    end
  end

  def destroy
    @membership_offer.destroy
    redirect_to admin_membership_offers_url, :notice => "Successfully destroyed membership offer."
  end

  private

  def membership_offer_params
    params.require(:membership_offer).permit(:name, :recurring_cost, :email_html, :html_description, :use_ticket_class_code,
                  :use_member_friend_code, :tickets_per_performance,
                  :billing_agreement, :myemma_group, :on_sale, :trial_period, :trial_price,
                  :restricted_to_first_time, :max_cycles_if_gift, :status)
  end
end
