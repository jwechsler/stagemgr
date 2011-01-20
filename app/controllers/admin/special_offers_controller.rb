class Admin::SpecialOffersController < Admin::ApplicationController
  def new
    @special_offer = SpecialOffer.new
  end
  
  def create
    @special_offer = SpecialOffer.new(params[:special_offer])
    @special_offer.type = params[:special_offer][:type]
    if @special_offer.save
      redirect_to admin_special_offers_path
    else
      render :new
    end
    
  end
  
  def index
    t_ids = Theater.where("status != 'Inactive'").map {|x| x.id}
    prod_ids = Production.where("status != 'Inactive'").map {|x| x.id}
    perf_ids = Performance.where("status != 'Inactive' and production_id in (?)",prod_ids).map {|x| x.id}
    
    @special_offers = SpecialOffer.where("theater_id in (?) or performance_id in (?)  or production_id in (?) or (theater_id is null and performance_id is null and production_id is null)",t_ids,perf_ids,prod_ids).order("performance_id, production_id, theater_id")
    render 'admin/scaffold/index'
  end
end
