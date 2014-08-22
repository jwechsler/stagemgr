class Admin::SpecialOffersController < Admin::ApplicationController
  filter_resource_access

  def new
    @special_offer = SpecialOffer.new
  end

  def create
    @special_offer = SpecialOffer.new(params[:special_offer])
    @special_offer.type = params[:special_offer][:type]
    if @special_offer.save
      redirect_to admin_special_offers_path, :notice=>"Created new special offer '#{@special_offer.code}"
    else
      redirect_to new_admin_special_offers_path
    end

  end

  def edit
    @special_offer = SpecialOffer.find(params[:id])

  end

  def update
    @special_offer = SpecialOffer.find(params[:id])
    possible_types =
    key = :special_offer
    object_type = [:percent_off_special_offer, :amount_off_special_offer, :ticket_class_special_offer].select {|t| params.has_key?(t)}.first

    @special_offer.attributes=params[object_type]
    if @special_offer.save
      flash[:notice] = "Offer updated"
      redirect_to admin_special_offers_path
    else
      render :edit
    end


  end

  def show
    @special_offer = SpecialOffer.find(params[:id])
  end

  def index
    t_ids = Theater.where("status != 'Inactive'").map {|x| x.id}
    prod_ids = Production.where("status != 'Inactive'").map {|x| x.id}
    perf_ids = Performance.where("status != 'Inactive' and production_id in (?)",prod_ids).map {|x| x.id}

    @special_offers = SpecialOffer.where("system_generated = 0 and (theater_id in (?) or performance_id in (?)  or production_id in (?) or (theater_id is null and performance_id is null and production_id is null))",t_ids,perf_ids,prod_ids).order("code, performance_id, production_id, theater_id")
    render :index
  end
end
