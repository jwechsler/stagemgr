class SeatAssignmentsController < ApplicationController
  before_filter :load_performance_and_seat_assignments
  def index
    respond_to do |format|
      format.html {
        raise "Action not allowed"
      }
      format.json {
        render json: @seat_assignments.map { |sa| { id: sa.id, seat_id:sa.seat_id, status:sa.status, label:sa.seat.location, origin_x: sa.seat.origin_x, origin_y: sa.seat.origin_y, width: sa.seat.width}}
      }
    end
  end

  def reserve
    respond_to do |format|
      format.html {
        raise "Action not allowed"
      }
      format.json {
        order = Order.find(params[:seat_assignment][:order_id])
        sa = SeatAssignment.find(params[:id])
        if sa.available? && ((current_user.nil? && order.processing?) || !current_user.nil?) then
          sa.status = SeatAssignment::TEMPORARY
          sa.order = order
          sa.save
          sa.reload
        end
        render json: {id: sa.id, seat_id:sa.seat_id, status:sa.status, order_id: sa.order_id }
      }
    end
  end

  def release
    respond_to do |format|
      format.html {
        raise "Action not allowed"
      }
      format.json {
        order = Order.find(params[:seat_assignment][:order_id])
        sa = SeatAssignment.find(params[:id])
        if sa.temporary? && (sa.order_id = order.id) && ((current_user.nil? && order.processing?) || !current_user.nil?) then
          sa.status = SeatAssignment::AVAILABLE
          sa.order = nil
          sa.save
          sa.reload
        end
        render json: {id: sa.id, seat_id:sa.seat_id, status:sa.status, order_id: sa.order_id }
      }
    end
  end

  private
  def load_performance_and_seat_assignments
    @performance = Performance.find(params[:performance_id])
    @seat_assignments = SeatAssignment.joins(:seat).where(performance_id: @performance.id)
    if @seat_assignments.empty? and !@performance.production.seat_map.nil? then
      @seat_assignments = @performance.production.seat_map.create_inventory_for_performance(@performance)
    end
    @seat_assignments.order(:originY, :originX)
  end
end
