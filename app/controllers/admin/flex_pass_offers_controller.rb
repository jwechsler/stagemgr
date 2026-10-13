class Admin::FlexPassOffersController < Admin::ApplicationController
  include ReturnsToOrigin

  load_and_authorize_resource except: %i[autocomplete_tag search resolve_group activate_selected deactivate_selected]

  def autocomplete_tag
    term = params[:term].to_s
    names = FlexPassOfferTag.where('name LIKE ?', "#{term}%")
                            .order(:name).limit(20).pluck(:name).uniq
    render json: names
  end

  # Offer-picker typeahead endpoints (reports page).
  def search
    authorize! :read, FlexPassOffer
    render json: OfferSearch.new(current_ability, 'flex_pass').search(params[:q])
  end

  def resolve_group
    authorize! :read, FlexPassOffer
    render json: OfferSearch.new(current_ability, 'flex_pass').resolve_group(params[:group_key])
  end

  def index
    respond_to do |format|
      format.html
      format.json do
        params.permit!
        render json: FlexPassOfferDatatable.new(params, view_context: view_context, current_user: current_user)
      end
    end
  end

  # POST /flex_pass_offers/activate_selected and deactivate_selected -- the
  #   index's Make Active / Make Inactive buttons (admins only). Each offer
  #   saves on its own, so one invalid offer does not block the rest;
  #   deactivating also takes an offer off public sale
  #   (FlexPassOffer#sync_active_with_public_sale).
  def activate_selected
    set_active_for_selected(true)
  end

  def deactivate_selected
    set_active_for_selected(false)
  end

  # GET /flex_pass_offers/1
  # GET /flex_pass_offers/1.json -- feeds the outstanding-passes table, as the
  #   membership page's redemptions table does
  # GET /flex_pass_offers/1.xml
  def show
    respond_to do |format|
      format.html { @usage = FlexPassOfferUsage.new(@flex_pass_offer) }
      format.json do
        params.permit!
        render json: FlexPassOfferPassesDatatable.new(params, current_user: current_user,
                                                              flex_pass_offer: @flex_pass_offer)
      end
      format.xml { render xml: @flex_pass_offer }
    end
  end

  # GET /flex_pass_offers/new
  # GET /flex_pass_offers/new.xml
  def new
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render xml: @flex_pass_offer }
    end
  end

  # GET /flex_pass_offers/1/edit
  def edit; end

  # POST /flex_pass_offers
  # POST /flex_pass_offers.xml
  def create
    respond_to do |format|
      if @flex_pass_offer.save
        flash[:notice] = 'FlexPassOffer was successfully created.'
        format.html { redirect_to(admin_flex_pass_offers_path) }
      else
        format.html { render action: 'new' }
      end
    end
  end

  # PUT /flex_pass_offers/1
  # PUT /flex_pass_offers/1.xml
  def update
    @flex_pass_offer.update(flex_pass_offer_params)
    respond_to do |format|
      if @flex_pass_offer.save
        flash[:notice] = 'FlexPassOffer was successfully updated.'
        format.html { redirect_to(return_to_path(admin_flex_pass_offer_path(@flex_pass_offer))) }
        format.xml  { head :ok }
      else
        format.html { render action: 'edit' }
        format.xml  { render xml: @flex_pass_offer.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /flex_pass_offers/1
  # DELETE /flex_pass_offers/1.xml
  def destroy
    @flex_pass_offer.destroy

    respond_to do |format|
      format.html do
        flash.keep
        # The admin listing, not the public one: `flex_pass_offers_url` named a
        # public index that has no controller (and no longer has a route).
        redirect_to(admin_flex_pass_offers_url)
      end
      format.xml { head :ok }
    end
  end

  private

  def set_active_for_selected(active)
    authorize! :bulk_update, FlexPassOffer
    offers = FlexPassOffer.accessible_by(current_ability, :update).where(id: Array(params[:ids]))
    failed = offers.reject { |offer| offer.update(active: active) }
    render json: {
      updated: offers.size - failed.size,
      failed: failed.map { |offer| { id: offer.id, name: offer.name, errors: offer.errors.full_messages.to_sentence } }
    }
  end

  def flex_pass_offer_params
    params.require(:flex_pass_offer).permit(:name, :price, :number_of_tickets, :use_ticket_class_code, :flat_payout, :spiff, :facility_fee,
                                            :short_description, :description, :active, :code_prefix, :maximum_uses_per_production, :maximum_uses_per_performance, :on_sale_to_public, :months_till_expiration, :festival_id, :theater_id, :exclude_theater, :redeem_immediately, :autofulfill_performance_codes, :tag_names)
  end
end
