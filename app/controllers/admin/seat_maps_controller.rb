class Admin::SeatMapsController < ApplicationController
  prepend_before_action :find_venue
  load_and_authorize_resource

  def index
    respond_to do |format|
      format.html # index.html.erb
      format.json {
        params.permit!
        render json: SeatMapDatatable.new(params, venue: @venue  )
      }
    end
  end

  def new
    @seat_map.venue = @venue
    @geometry_import = FileStore.new
    @geometry_import.format = FileStore::SEATMAP_GEOMETRY
    # @seat_map = SeatMap.new
  end

  def show
  end

  def edit
    @geometry_import = FileStore.new
    @geometry_import.format = FileStore::SEATMAP_GEOMETRY
  end

  def update
    respond_to do |format|
      update_geometry(params[:seat_map][:geometry_import]) unless params[:seat_map][:geometry_import].nil?
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
    update_geometry(params[:seat_map][:geometry_import]) unless params[:seat_map][:geometry_import].nil?
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

  def update_geometry(geometry_import)
    headers = nil
    total = 0
    merged = 0
    location_idx = 0
    row_idx = 0
    sequence_idx = 0
    origin_x_idx = 0
    origin_y_idx = 0
    width_idx = 0
    height_idx = 0
    feature_idx = 0
    CSV.foreach(geometry_import.path) do |row|
      if headers.nil? then


        _index = 0
        headers = Hash[row.map {|header| _index += 1; [header, _index]}]
        headers.keys.each {|key|
          encoding_options = {
          :invalid           => :replace,  # Replace invalid byte sequences
            :undef             => :replace,  # Replace anything not defined in ASCII
            :replace           => '',        # Use a blank for those replacements
            :universal_newline => true       # Always break lines with \n
          }
          stripped_key = key.encode(Encoding.find('ASCII'), encoding_options)
          headers[stripped_key] = headers.delete(key)
        }
        location_idx = headers['location'] - 1
        row_idx = headers['row'] - 1
        sequence_idx = headers['sequence'] - 1
        origin_x_idx = headers['origin-x'] - 1
        origin_y_idx = headers['origin-y'] - 1
        width_idx = headers['width'] - 1
        height_idx = headers['height'] - 1
        feature_idx = headers['feature'] - 1

      else
        total += 1
        seat = @seat_map.seats.select{|s|
          s.location.eql?(row[location_idx])}.first
        if seat.nil?
          seat ||= Seat.new(location: row[location_idx])
          @seat_map.seats << seat
        end
        seat.row = row[row_idx]
        seat.seat_number = row[sequence_idx]
        seat.origin_x = row[origin_x_idx]
        seat.origin_y = row[origin_y_idx]
        seat.width = row[width_idx]
        seat.height = row[height_idx]
        seat.feature = row[feature_idx]
        seat.save
        
      end
    end

    productions = Production.where(seat_map_id: @seat_map.id)
    productions.each do |prod|
      prod.performances.each do |perf|
        @seat_map.create_inventory_for_performance(perf)
      end
    end

  end

  def seat_map_params
    params.require(:seat_map).permit(:label, :base_image_map, :venue_id)
  end

  def find_venue
    @venue=Venue.find(params[:venue_id])
  end

end
