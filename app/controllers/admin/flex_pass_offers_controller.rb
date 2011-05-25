class Admin::FlexPassOffersController < Admin::ApplicationController
  filter_resource_access

  def index
    @flex_pass_offers = FlexPassOffer.all
    @flex_pass_offers = @flex_pass_offers.select {|o|
      backend_user? || current_user.theater_ids.include?(o.theater_id) }
  end

  # GET /flex_pass_offers/1
  # GET /flex_pass_offers/1.xml
  def show

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @flex_pass_offer }
    end
  end

  # GET /flex_pass_offers/new
  # GET /flex_pass_offers/new.xml
  def new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @flex_pass_offer }
    end
  end

  # GET /flex_pass_offers/1/edit
  def edit
    @flex_pass_offer = FlexPassOffer.find(params[:id])
  end

  # POST /flex_pass_offers
  # POST /flex_pass_offers.xml
  def create

    respond_to do |format|
      if @flex_pass_offer.save
        flash[:notice] = 'FlexPassOffer was successfully created.'
        format.html { redirect_to(admin_flex_pass_offers_path) }
      else
        format.html { render :action => "new" }
      end
    end
  end

  # PUT /flex_pass_offers/1
  # PUT /flex_pass_offers/1.xml
  def update

    respond_to do |format|
      if @flex_pass_offer.update_attributes(params[:flex_pass_offer])
        flash[:notice] = 'FlexPassOffer was successfully updated.'
        format.html { redirect_to([:admin,@flex_pass_offer]) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @flex_pass_offer.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /flex_pass_offers/1
  # DELETE /flex_pass_offers/1.xml
  def destroy
    @flex_pass_offer.destroy

    respond_to do |format|
      format.html { redirect_to(flex_pass_offers_url) }
      format.xml  { head :ok }
    end
  end

end
