class Admin::FlexPassOffersController < Admin::ApplicationController
  load_and_authorize_resource

  def index
    respond_to do |format|
      format.html
      format.json do
        params.permit!
        render json: FlexPassOfferDatatable.new(params, view_context: view_context, current_user: current_user)
      end
    end
  end

  # GET /flex_pass_offers/1
  # GET /flex_pass_offers/1.xml
  def show
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render xml: @flex_pass_offer }
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
        format.html { redirect_to([:admin, @flex_pass_offer]) }
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
        redirect_to(flex_pass_offers_url)
      end
      format.xml { head :ok }
    end
  end

  private

  def flex_pass_offer_params
    params.require(:flex_pass_offer).permit(:name, :price, :number_of_tickets, :use_ticket_class_code, :flat_payout, :spiff, :facility_fee,
                                            :short_description, :description, :active, :code_prefix, :maximum_uses_per_production, :on_sale_to_public, :months_till_expiration, :treat_as_festival_pass, :theater_id, :exclude_theater, :redeem_immediately)
  end
end
