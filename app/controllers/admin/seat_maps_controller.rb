class Admin::SeatMapsController < Admin::ApplicationController
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

  # The standalone show page was retired in favor of opening the graphical
  # editor directly; keep old links/bookmarks working.
  def show
    redirect_to editor_admin_venue_seat_map_path(@venue, @seat_map)
  end

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

  # A geometry file that cannot be read or lacks a required column stops the
  # whole request: no seat map is created and nothing is imported. Otherwise
  # the seat map is saved first and the file imported into it.
  def create
    @seat_map.venue = @venue
    import = geometry_import
    return render_with_import_problem('new', import) if import && !import.check.importable?
    return render(action: 'new') unless @seat_map.save

    flash[:notice] = "SeatMap '#{@seat_map.label}' was successfully created for venue #{@seat_map.venue.name}."
    report_import(run_import(import)) if import
    redirect_to(admin_venue_path(@venue))
  end

  # As create: a bad geometry file leaves the seat map unchanged, including
  # the other submitted attributes.
  def update
    import = geometry_import
    respond_to do |format|
      if import && !import.check.importable?
        format.html { render_with_import_problem('edit', import) }
      elsif @seat_map.update(seat_map_params)
        flash[:notice] = "SeatMap '#{@seat_map.label}' was successfully updated."
        report_import(run_import(import)) if import
        format.html { redirect_to(admin_venue_path(@venue)) }
      else
        format.html { render action: 'edit' }
      end
    end
  end

  def destroy
    flash[:error] = @seat_map.errors.full_messages.to_sentence unless @seat_map.destroy
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
          deletable: undeletable_seat_ids.exclude?(seat.id)
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
      params.permit(seats: %i[id op client_id location row seat_number
                              origin_x origin_y width height zone feature])
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
                  .exists?(["(order_uuid IS NOT NULL AND order_uuid <> '') OR status IN (:held)", { held: [SeatAssignment::TEMPORARY, SeatAssignment::ASSIGNED] }])
  end

  def geometry_import
    file = params.dig(:seat_map, :geometry_import).presence
    file && SeatGeometryImport.new(@seat_map, file)
  end

  def run_import(import)
    import.call.tap { |result| rebuild_inventory_for_seat_map if result.importable? }
  end

  # Imports a geometry file into the (saved) seat map and rebuilds inventory.
  def update_geometry(geometry_file)
    run_import(SeatGeometryImport.new(@seat_map, geometry_file))
  end

  def render_with_import_problem(action, import)
    flash.now[:error] = import.check.problem_message
    render action: action
  end

  # Flash messages are plain text; the layout escapes them.
  def report_import(result)
    flash[:notice] = [flash[:notice], result.summary_message].compact.join(' ')
    flash[:warning] = result.skipped_message if result.skipped_rows.any?
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
