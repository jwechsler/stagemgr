class FestivalsController < ApplicationController
  layout Rails.configuration.x.server_config['ext_site_wrapper']

  rescue_from ActiveRecord::RecordNotFound do
    render '/general/unavailable', status: :not_found
  end

  def show
    @festival = Festival.active.where(landing_page_enabled: true).find_by!(slug: params[:slug])
  end
end
