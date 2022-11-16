class Admin::VenuesController < ApplicationController
  load_and_authorize_resource

  def index
    respond_to do |format|
      format.html # index.html.erb
      format.json {
        params.permit!
        render json: VenueDatatable.new(params, view_context: view_context, current_user: current_user )
      }
    end
  end

  def show
  end

  def new
  end

  def create
    if @venue.save
      redirect_to [:admin, @venue], :notice => "Successfully created venue."
    else
      render :action => 'new'
    end
  end

  def edit
    @venue = Venue.find(params[:id])
  end

  def update

    if @venue.update(venue_params)
      redirect_to [:admin, @venue], :success  => "Successfully updated venue."
    else
      render :action => 'edit'
    end
  end

  def destroy
    @venue = Venue.find(params[:id])
    @venue.destroy
    redirect_to admin_venues_url, :notice => "Successfully destroyed venue."
  end

  private
  def venue_params
    params.require(:venue).permit(:name, :ordinal_sort)
  end
end
