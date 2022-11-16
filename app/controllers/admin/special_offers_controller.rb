class Admin::SpecialOffersController < Admin::ApplicationController
  authorize_resource

  def new
    @special_offer = SpecialOffer.new
  end

  def create
    @special_offer = SpecialOffer.new(special_offer_params)
    @special_offer.type = params[:special_offer][:type]
    if @special_offer.save
      redirect_to admin_special_offers_path, :notice=>"Created new special offer '#{@special_offer.code}'"
    else
      flash[:error] = @special_offer.errors.first.message unless @special_offer.errors.empty?
      render :action => 'new'
    end
  end

  def edit
    @special_offer = SpecialOffer.find(params[:id])
  end

  def update
    @special_offer = SpecialOffer.find(params[:id])
    key = :special_offer
    object_type = [:percent_off_special_offer, :amount_off_special_offer, :ticket_class_special_offer].select {|t| params.has_key?(t)}.first
    @special_offer.update(special_offer_params(object_type))
    @special_offer.limiting_model_type=params[object_type][:limiting_model_type]
    @special_offer.limiting_id = params[object_type][:limiting_id]

    if @special_offer.save
      flash[:notice] = "Offer updated"
      redirect_to admin_special_offers_path
    else
      render :edit
    end

  end

  def show
  end

  def index
    respond_to do |format|
      format.html
      format.json {
        params.permit!
        render json: SpecialOfferDatatable.new(params)
      }
    end
  end

  private
  def special_offer_params(object_type = :special_offer)
    params.require(object_type).permit(
      :code, :type, :status, :limiting_model_type, :limiting_id, :amount,
      :change_ticket_class_code, :ticket_class_code, :performance_start_range, :performance_end_range,
      :restricted_monday, :restricted_tuesday, :restricted_wednesday, :restricted_thursday, :restricted_friday,
      :restricted_saturday, :restricted_sunday, :auto_start, :auto_expire, :number_of_uses,
      :max_tickets_per_order)
  end

end
