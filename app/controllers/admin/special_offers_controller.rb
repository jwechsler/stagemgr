class Admin::SpecialOffersController < Admin::ApplicationController
  authorize_resource

  # simple_form namespaces the posted fields under the STI subclass name, so
  # the param key itself tells us which offer type is being created/updated.
  OFFER_PARAM_KEYS = %i[percent_off_special_offer amount_off_special_offer
                        ticket_class_special_offer buy_x_get_y_special_offer].freeze

  def index
    respond_to do |format|
      format.html
      format.json do
        params.permit!
        render json: SpecialOfferDatatable.new(params)
      end
    end
  end

  def show; end

  def new
    offer_class = SpecialOffer::OFFER_TYPES.key?(params[:type]) && params[:type].constantize
    if offer_class
      @special_offer = offer_class.new
    else
      redirect_to admin_special_offers_path,
                  alert: 'Pick the kind of special offer to create with one of the Add buttons.'
    end
  end

  def edit
    @special_offer = SpecialOffer.find(params[:id])
  end

  def create
    object_type = posted_offer_param_key
    @special_offer = object_type.to_s.camelize.constantize.new(special_offer_params(object_type))
    if @special_offer.save
      redirect_to admin_special_offers_path, notice: "Created new special offer '#{@special_offer.code}'"
    else
      flash[:error] = @special_offer.errors.first.message unless @special_offer.errors.empty?
      render action: 'new'
    end
  end

  def update
    @special_offer = SpecialOffer.find(params[:id])
    object_type = posted_offer_param_key
    @special_offer.update(special_offer_params(object_type))
    @special_offer.limiting_model_type = params[object_type][:limiting_model_type]
    @special_offer.limiting_id = params[object_type][:limiting_id]

    if @special_offer.save
      flash[:notice] = 'Offer updated'
      redirect_to admin_special_offers_path
    else
      render :edit
    end
  end

  def duplicate
    @special_offer = SpecialOffer.find(params[:id])
    object_type = posted_offer_param_key
    @special_offer.update(special_offer_params(object_type))
    @special_offer.limiting_model_type = params[object_type][:limiting_model_type]
    @special_offer.limiting_id = params[object_type][:limiting_id]

    if @special_offer.save
      original = @special_offer
      @special_offer = @special_offer.dup
      @special_offer.code = nil
      @special_offer.limiting_model_type = original.limiting_model_type
      @special_offer.limiting_id = original.limiting_id
      render :new
    else
      render :edit
    end
  end

  private

  def posted_offer_param_key
    OFFER_PARAM_KEYS.find { |key| params.key?(key) } ||
      raise(ActionController::ParameterMissing, :special_offer)
  end

  def special_offer_params(object_type)
    params.require(object_type).permit(
      :code, :status, :limiting_model_type, :limiting_id, :amount,
      :change_ticket_class_code, :ticket_class_code, :performance_start_range, :performance_end_range,
      :restricted_monday, :restricted_tuesday, :restricted_wednesday, :restricted_thursday, :restricted_friday,
      :restricted_saturday, :restricted_sunday, :auto_start, :auto_expire, :number_of_uses,
      :max_tickets_per_order, :buy_quantity, :get_quantity
    )
  end
end
