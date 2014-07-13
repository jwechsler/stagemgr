class Admin::SpecialFeaturesController < ApplicationController
  filter_resource_access

  def index
    @special_features = SpecialFeature.all
  end

  def show
    @special_feature = SpecialFeature.find(params[:id])
  end

  def new
    @special_feature = SpecialFeature.new
  end

  def create
    @special_feature = SpecialFeature.new(params[:special_feature])
    if @special_feature.save
      redirect_to [:admin, :special_features], :notice => "Successfully created special feature."
    else
      render :action => 'new'
    end
  end

  def edit
    @special_feature = SpecialFeature.find(params[:id])
  end

  def update
    @special_feature = SpecialFeature.find(params[:id])
    if @special_feature.update_attributes(params[:special_feature])
      redirect_to [:admin, :special_features], :notice  => "Successfully updated special feature."
    else
      render :action => 'edit'
    end
  end

  def destroy
    @special_feature = SpecialFeature.find(params[:id])
    @special_feature.destroy
    redirect_to admin_special_features_url, :notice => "Successfully destroyed special feature."
  end
end
