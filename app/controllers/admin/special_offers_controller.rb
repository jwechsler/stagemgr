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
    @special_offers = SpecialOffer.all
    render 'admin/scaffold/index'
  end
end
