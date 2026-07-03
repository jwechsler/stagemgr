require 'csv'

class Admin::SeatMapsController < ApplicationController
  prepend_before_action :find_venue
  load_and_authorize_resource

  def index
    respond_to do |format|
      format.html # index.html.erb
      format.json do
        params.permit!
        render json: SeatMapDatatable.new(params, venue: @venue, view_context: view_context, current_user: current_user)
      end
    end
  end

  def show; end

  def new
    @seat_map.venue = @venue
    @geometry_import = FileStore.new
    @geometry_import.format = FileStore::SEATMAP_GEOMETRY
    # @seat_map = SeatMap.new
  end

  def edit
    @geometry_import = FileStore.new
    @geometry_import.format = FileStore::SEATMAP_GEOMETRY
  end

  def create
    @seat_map.venue = @venue
    update_geometry(params[:seat_map][:geometry_import]) unless params[:seat_map][:geometry_import].nil?
    if @seat_map.save!
      flash[:notice] = "SeatMap '#{@seat_map.label}' was successfully created for venue #{@seat_map.venue.name}."
      redirect_to(admin_venue_path(@venue))
    else
      render action: 'edit'
    end
  end

  def update
    respond_to do |format|
      update_geometry(params[:seat_map][:geometry_import]) unless params[:seat_map][:geometry_import].nil?
      if @seat_map.update(seat_map_params)
        flash[:notice] = "SeatMap '#{@seat_map.label}' was successfully updated."
        format.html { redirect_to(admin_venue_path(@venue)) }
      else
        format.html { render action: 'edit' }
      end
    end
  end

  def destroy
    @seat_map.destroy
    respond_to do |format|
      format.html { redirect_to(admin_venue_path(@venue)) }
    end
  end

  # Full-screen graphical seat map editor (geometry + zones). Loads its data
  # via editor_data and saves in one batch via bulk_update_seats.
  def editor; end

  def editor_data
    # One grouped query for per-seat sale/hold state (no N+1): a seat is not
    # deletable once any assignment is tied to an order or holds/assigns a
    # patron, matching Seat#verify_unassigned plus live Held/Assigned holds.
    undeletable_seat_ids = SeatAssignment
                           .where(seat_id: @seat_map.seats.select(:id))
                           .where("(order_uuid IS NOT NULL AND order_uuid <> '') OR status IN (:held)",
                                  held: [SeatAssignment::TEMPORARY, SeatAssignment::ASSIGNED])
                           .distinct.pluck(:seat_id).to_set

    render json: {
      seat_map: {
        id: @seat_map.id,
        label: @seat_map.label,
        present_as_zoned: @seat_map.present_as_zoned,
        image_url: @seat_map.base_image_map.attached? ? url_for(@seat_map.base_image_map) : nil,
        width: @seat_map.base_image_map.attached? ? @seat_map.original_width : nil,
        height: @seat_map.base_image_map.attached? ? @seat_map.original_height : nil
      },
      seats: @seat_map.seats.order(:row, :seat_number).map do |seat|
        {
          id: seat.id,
          location: seat.location,
          row: seat.row,
          seat_number: seat.seat_number,
          origin_x: seat.origin_x,
          origin_y: seat.origin_y,
          width: seat.width,
          height: seat.height,
          zone: seat.zone,
          feature: seat.feature,
          deletable: !undeletable_seat_ids.include?(seat.id)
        }
      end
    }
  end

  # Batch save from the editor: {seats: [{op: create|update|delete, ...}]}.
  # Seat mutations are all-or-nothing; the (idempotent) inventory rebuild runs
  # after commit so a long rebuild never holds row locks against live sales.
  def bulk_update_seats
    id_map = {}
    ActiveRecord::Base.transaction do
      params.permit(seats: [:id, :op, :client_id, :location, :row, :seat_number,
                            :origin_x, :origin_y, :width, :height, :zone, :feature])
            .fetch(:seats, []).each do |seat_params|
        case seat_params[:op]
        when 'delete'
          seat = @seat_map.seats.find(seat_params[:id])
          if seat_in_use?(seat)
            raise BulkSeatError, "Seat #{seat.location} has sold or held tickets and cannot be deleted."
          end

          seat.destroy!
        when 'create'
          seat = @seat_map.seats.create!(seat_attrs(seat_params))
          id_map[seat_params[:client_id]] = seat.id if seat_params[:client_id]
        when 'update'
          seat = @seat_map.seats.find(seat_params[:id])
          seat.update!(seat_attrs(seat_params))
        end
      end
    end

    rebuild_inventory_for_seat_map
    render json: { status: 'ok', id_map: id_map }
  rescue BulkSeatError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed => e
    render json: { status: 'error', message: e.message }, status: :unprocessable_entity
  end

  private

  class BulkSeatError < StandardError; end

  def seat_attrs(seat_params)
    seat_params.slice(:location, :row, :seat_number, :origin_x, :origin_y,
                      :width, :height, :zone, :feature).to_h.compact
  end

  # A seat is in use once any assignment ties it to an order (sold) or holds
  # it for a live checkout (Held/Assigned). Geometry and zone edits remain
  # allowed for in-use seats; deletion is not.
  def seat_in_use?(seat)
    SeatAssignment.where(seat_id: seat.id)
                  .where("(order_uuid IS NOT NULL AND order_uuid <> '') OR status IN (:held)",
                         held: [SeatAssignment::TEMPORARY, SeatAssignment::ASSIGNED])
                  .exists?
  end

  def update_geometry(geometry_import)
    headers = nil
    total = 0
    location_idx = 0
    row_idx = 0
    sequence_idx = 0
    origin_x_idx = 0
    origin_y_idx = 0
    width_idx = 0
    height_idx = 0
    feature_idx = 0
    zone_idx = nil
    CSV.foreach(geometry_import.path) do |row|
      if headers.nil?

        _index = 0
        headers = Hash[row.map do |header|
          _index += 1
          [header, _index]
        end]
        headers.keys.each do |key|
          encoding_options = {
            invalid: :replace, # Replace invalid byte sequences
            undef: :replace, # Replace anything not defined in ASCII
            replace: '', # Use a blank for those replacements
            universal_newline: true # Always break lines with \n
          }
          # Ruby 3: options must be passed as keywords — a positional hash is
          # interpreted as a source encoding and raises TypeError.
          stripped_key = key.encode(Encoding.find('ASCII'), **encoding_options)
          headers[stripped_key] = headers.delete(key)
        end
        location_idx = headers['location'] - 1
        row_idx = headers['row'] - 1
        sequence_idx = headers['sequence'] - 1
        origin_x_idx = headers['origin-x'] - 1
        origin_y_idx = headers['origin-y'] - 1
        width_idx = headers['width'] - 1
        height_idx = headers['height'] - 1
        feature_idx = headers['feature'] - 1
        # Zoned pricing: the zone column is optional. When absent, existing
        # seat zones are left untouched on re-import.
        zone_idx = headers['zone'].nil? ? nil : headers['zone'] - 1

      else
        total += 1
        seat = @seat_map.seats.select do |s|
          s.location.eql?(row[location_idx])
        end.first
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
        # A blank cell under a present zone column resets the seat to the
        # default zone "A" (Seat#normalize_zone).
        seat.zone = row[zone_idx] unless zone_idx.nil?
        seat.save

      end
    end

    rebuild_inventory_for_seat_map
  end

  # Materializes SeatAssignment inventory for every performance of every
  # production using this seat map. Idempotent: create_inventory_for_performance
  # skips seats that already have an assignment, so this only inserts rows for
  # newly added seats. Shared by the CSV geometry import and the seat map
  # editor bulk save.
  def rebuild_inventory_for_seat_map
    productions = Production.where(seat_map_id: @seat_map.id)
    productions.each do |prod|
      prod.performances.each do |perf|
        @seat_map.create_inventory_for_performance(perf)
      end
    end
  end

  def seat_map_params
    params.require(:seat_map).permit(:label, :base_image_map, :venue_id, :present_as_zoned)
  end

  def find_venue
    @venue = Venue.find(params[:venue_id])
  end
end
