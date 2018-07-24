class Admin::SeatMapsController < ApplicationController
  prepend_before_filter :find_venue
  load_and_authorize_resource

  def index
    respond_to do |format|
      format.html # index.html.erb
      format.json {
        params.permit!
        render json: SeatMapDatatable.new(params, view_context: view_context, current_user: current_user, venue: @venue  )
      }
    end
  end

  def new
    @seat_map.venue = @venue
    # @seat_map = SeatMap.new
  end

  def show
  end

  def edit
  end

  def update
    respond_to do |format|
      if @seat_map.update_attributes(seat_map_params)
        flash[:notice] = "SeatMap '#{@seat_map.label}' was successfully updated."
        format.html { redirect_to(admin_venue_path(@venue)) }
      else
        format.html { render :action => "edit" }
      end
    end
  end

  def create
    @seat_map.venue = @venue
    if @seat_map.save!
      flash[:notice] = "SeatMap '#{@seat_map.label}' was successfully created for venue #{@seat_map.venue.name}."
      redirect_to(admin_venue_path(@venue))
    else
      render :action=>"edit"
    end
  end

  def destroy
    @seat_map.destroy
    respond_to do |format|
      format.html { redirect_to(admin_venue_path(@venue)) }
    end
  end


  private
  def seat_map_params
    params.require(:seat_map).permit(:label, :base_image_map, :venue_id)
  end

  def find_venue
    @venue=Venue.find(params[:venue_id])
  end

end
