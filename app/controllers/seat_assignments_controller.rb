class SeatAssignmentsController < ApplicationController
  helper SeatAssignmentHelper

  expose :performance, ->{
    Performance.find(params[:performance_id])
  }

  expose :seat_assignments, ->{
    sa = SeatAssignment.includes(:seat).joins(:seat).where(performance_id: performance.id).merge(Seat.order(:origin_y,  :origin_x))
    if sa.empty? and !performance.production.seat_map.nil? then
      sa = performance.production.seat_map.create_inventory_for_performance(performance)
    end
    sa
  }

  # before_filter :load_performance_and_seat_assignments
  def index
    respond_to do |format|
      format.html {
        render partial:"available_seatmap", locals:{ticket_order_uuid: params[:ticket_order_uuid], performance: performance}
      }
      format.json {
        render json: seat_assignments.map { |sa| { id: sa.id, seat_id:sa.seat_id, status:sa.status, label:sa.seat.location, origin_x: sa.seat.origin_x, origin_y: sa.seat.origin_y, width: sa.seat.width, accessible: sa.seat.accessible?}}
      }
    end
  end

  def reserve
    respond_to do |format|
      format.html {
        raise "Action not allowed"
      }
      format.json {
        order_uuid = params[:order_uuid]
        ticket_class_id = params[:ticket_class_id]
        max_tickets = params[:max_tickets]
        accessible_setting = params[:accessible]
        unless order_uuid.nil?
          sa = SeatAssignment.find(params[:id])
          unless (!max_tickets.nil? && current_assignment_count(order_uuid,sa.id) >= max_tickets.to_i)
            sa.assign_to_order(order_uuid, 20, ticket_class_id.to_i, accessible_setting) if sa.available?(order_uuid)
          end
          status = view_context.assignment_keys(sa, order_uuid)
          render json: {id: sa.id, status:status, order_uuid: sa.order_uuid,
            unavailable: unavailable_seating_report(order_uuid, sa.performance_id),
            current_seat_assignments: SeatAssignment.seating_as_list(order_uuid, [SeatAssignment::TEMPORARY, SeatAssignment::ASSIGNED]),
            ticket_count: current_assignment_count(order_uuid)
          }
        end
      }
    end
  end

  def release
    respond_to do |format|
      format.html {
        raise "Action not allowed"
      }
      format.json {
        order_uuid = params[:order_uuid]
        sa = SeatAssignment.find(params[:id])
        reseating = params[:reseating]
        if reseating.nil?
          sa.unassign_from_order(order_uuid) if sa.assigned?(order_uuid)
        else
          sa.begin_release_from_order(order_uuid) if sa.assigned?(order_uuid)
        end
        status = view_context.assignment_keys(sa, order_uuid)
        render json: { id: sa.id, status:status, order_uuid: sa.order_uuid,
          current_seat_assignments: SeatAssignment.seating_as_list(order_uuid, [SeatAssignment::TEMPORARY, SeatAssignment::ASSIGNED]),
          ticket_class_id: sa.ticket_class_id, unavailable: unavailable_seating_report(order_uuid, sa.performance_id),
          ticket_count: current_assignment_count(order_uuid)
        }
      }
    end
  end

  def release_temporary
    respond_to do |format|
      format.html {
        raise "Action not allowed"
      }
      format.json {
        order_uuid = params[:order_uuid]
        num_updated = SeatAssignment.where("order_uuid = :order_uuid and status = :temp_assignment and performance_id <> :performance_id",
          order_uuid: order_uuid, temp_assignment: SeatAssignment::TEMPORARY,
          performance_id: params['exclude_performance_id'].to_i).update_all(order_uuid: nil, updated_at: Time.now, status: SeatAssignment::AVAILABLE)
        render json: {status: "released"}
      }
    end
  end

  def commit_reseating
    respond_to do |format|
      format.html {
        raise "Action not allowed"
      }
      format.json {
        order_uuid = params[:order_uuid]
        result = SeatAssignment.reseating_commit(order_uuid)
        render json: {status: result,
          current_seat_assignments: SeatAssignment.seating_as_list(order_uuid, [SeatAssignment::TEMPORARY, SeatAssignment::ASSIGNED])
        }
      }
    end
  end

  def rollback_reseating
    respond_to do |format|
      format.html {
        raise "Action not allowed"
      }
      format.json {
        order_uuid = params[:order_uuid]
        SeatAssignment.reseating_rollback(order_uuid)
        render json: {status: "success"}
      }
    end
  end

  def unavailable_seating_report(order_uuid,performance_id)
    SeatAssignment.where(
      "performance_id = :performance_id and order_uuid <> :order_uuid and status not in(:available_status)",
      performance_id: performance_id,
      order_uuid: order_uuid,
      available_status: SeatAssignment::AVAILABLE).all.map {|sa|
        sa.id }
  end

  protected
  def current_assignment_count(order_uuid, exclude_sa_id = nil)
    SeatAssignment.current_seat_assignments(order_uuid, exclude_sa_id).count
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
