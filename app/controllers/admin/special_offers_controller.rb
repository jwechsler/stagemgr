class Admin::SpecialOffersController < Admin::ApplicationController
  before_filter :find_context
  def new
    @special_offer = @context.special_offers.build
  end
  
  def create
    @special_offer = @context.special_offers.build(params[:special_offer])
    @special_offer.type = params[:special_offer][:type]
    if @special_offer.save
      redirect_to url_for(@rest_path)
    else
      render :new
    end
    
  end
end
