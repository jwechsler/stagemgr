class Admin::MembershipOffersController < ApplicationController
  load_and_authorize_resource except: %i[autocomplete_tag search resolve_group]

  def autocomplete_tag
    term = params[:term].to_s
    names = MembershipOfferTag.where('name LIKE ?', "#{term}%")
                              .order(:name).limit(20).pluck(:name).uniq
    render json: names
  end

  # Offer-picker typeahead endpoints (reports page).
  def search
    authorize! :read, MembershipOffer
    render json: OfferSearch.new(current_ability, 'membership').search(params[:q])
  end

  def resolve_group
    authorize! :read, MembershipOffer
    render json: OfferSearch.new(current_ability, 'membership').resolve_group(params[:group_key])
  end

  def index
    respond_to do |format|
      format.html
      format.json do
        params.permit!
        render json: MembershipOfferDatatable.new(params, view_context: view_context)
      end
    end
  end

  def show; end

  def new
    @membership_offer = MembershipOffer.new
  end

  def edit; end

  def create
    @membership_offer = MembershipOffer.new(membership_offer_params)
    if @membership_offer.save
      redirect_to [:admin, @membership_offer], notice: 'Successfully created membership offer.'
    else
      render action: 'new'
    end
  end

  def update
    if @membership_offer.update(membership_offer_params)
      redirect_to [:admin, @membership_offer], success: 'Successfully updated membership offer.'
    else
      render action: 'edit'
    end
  end

  def destroy
    @membership_offer.destroy
    redirect_to admin_membership_offers_url, notice: 'Successfully destroyed membership offer.'
  end

  private

  def membership_offer_params
    params.require(:membership_offer).permit(:name, :email_html, :html_description, :use_ticket_class_code,
                                             :use_member_friend_code, :tickets_per_performance,
                                             :billing_agreement, :myemma_group, :on_sale, :trial_period,
                                             :restricted_to_first_time, :max_cycles_if_gift, :status, :price_id,
                                             :max_festival_tickets_in_advance, :tag_names)
  end
end
