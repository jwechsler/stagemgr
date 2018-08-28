class Admin::SpecialFeaturesController < ApplicationController
  load_and_authorize_resource

  def index
  end

  def show
  end

  def new
  end

  def create
    if @special_feature.save
      redirect_to [:admin, :special_features], :notice => "Successfully created special feature."
    else
      render :action => 'new'
    end
  end

  def edit
  end

  def update
    if @special_feature.update_attributes(special_feature_params)
      redirect_to [:admin, :special_features], :notice  => "Successfully updated special feature."
    else
      render :action => 'edit'
    end
  end

  def destroy
    @special_feature.destroy
    redirect_to admin_special_features_url, :notice => "Successfully destroyed special feature."
  end

  private
  def special_feature_params
    params.require(:special_feature).permit(:short_name, :description,:status)
  end

end
