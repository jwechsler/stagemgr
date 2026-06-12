class Admin::SpecialFeaturesController < ApplicationController
  load_and_authorize_resource

  def index
    respond_to do |format|
      format.html # index.html.erb
      format.json do
        params.permit!
        render json: SpecialFeatureDatatable.new(params, view_context: view_context, current_user: current_user)
      end
    end
  end

  def show; end

  def new; end

  def edit; end

  def create
    if @special_feature.save
      redirect_to %i[admin special_features], notice: 'Successfully created special feature.'
    else
      render action: 'new'
    end
  end

  def update
    if @special_feature.update(special_feature_params)
      redirect_to %i[admin special_features], success: 'Successfully updated special feature.'
    else
      render action: 'edit'
    end
  end

  def destroy
    @special_feature.destroy
    redirect_to admin_special_features_url, notice: 'Successfully destroyed special feature.'
  end

  private

  def special_feature_params
    params.require(:special_feature).permit(:short_name, :description, :status)
  end
end
