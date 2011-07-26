class Admin::VenuesController < ApplicationController
  def index
    @venues = Venue.all
  end

  def show
    @venue = Venue.find(params[:id])
  end

  def new
    @venue = Venue.new
  end

  def create
    @venue = Venue.new(params[:venue])
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
    @venue = Venue.find(params[:id])
    if @venue.update_attributes(params[:venue])
      redirect_to [:admin, @venue], :notice  => "Successfully updated venue."
    else
      render :action => 'edit'
    end
  end

  def destroy
    @venue = Venue.find(params[:id])
    @venue.destroy
    redirect_to admin_venues_url, :notice => "Successfully destroyed venue."
  end
end
