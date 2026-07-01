class SeatAssignmentsController < ApplicationController
  protect_from_forgery with: :null_session
  helper SeatAssignmentHelper

  expose :performance, lambda {
    Performance.find(params[:performance_id])
  }

  expose :seat_assignments, lambda {
    sa = SeatAssignment.includes(:seat).joins(:seat).where(performance_id: performance.id).merge(Seat.order(:origin_y, :origin_x))
    if sa.empty? and !performance.production.seat_map.nil?
      sa = performance.production.seat_map.create_inventory_for_performance(performance)
    end
    sa
  }

  # before_action :load_performance_and_seat_assignments
  def index
    respond_to do |format|
      format.html do
        render partial: 'available_seatmap',
               locals: { ticket_order_uuid: params[:ticket_order_uuid], performance: performance }
      end
      format.json do
        render json: seat_assignments.map { |sa|
          { id: sa.id, seat_id: sa.seat_id, status: sa.status, label: sa.seat.location, origin_x: sa.seat.origin_x,
            origin_y: sa.seat.origin_y, width: sa.seat.width, accessible: sa.seat.accessible? }
        }
      end
    end
  end

  def reserve
    respond_to do |format|
      format.html do
        raise 'Action not allowed'
      end
      format.json do
        order_uuid = params[:order_uuid]
        ticket_class_id = params[:ticket_class_id]
        max_tickets = params[:max_tickets]
        accessible_setting = params[:accessible]
        price_override = parse_price_override(params[:price_override], ticket_class_id)
        unless order_uuid.nil?
          max_seatable = can?(:seat_unlimited, SeatAssignment) ? 9999 : 20
          sa = SeatAssignment.find(params[:id])
          tli_id = nil
          unless !max_tickets.nil? && current_assignment_count(order_uuid, sa.id) >= max_tickets.to_i
            SeatAssignment.transaction do
              if sa.available?(order_uuid)
                sa.assign_to_order(order_uuid, max_seatable, ticket_class_id.to_i, accessible_setting)
                sa.update(price_override: price_override) if price_override
                tli_id = upsert_ticket_line_item_for(sa, order_uuid, price_override)
              end
            end
          end
          status = view_context.assignment_keys(sa, order_uuid)
          render json: { id: sa.id, status: status, order_uuid: sa.order_uuid,
                         ticket_class_id: sa.ticket_class_id,
                         price_override: sa.price_override,
                         seat_label: sa.seat&.location,
                         ticket_line_item_id: tli_id,
                         unavailable: unavailable_seating_report(order_uuid, sa.performance_id),
                         current_seat_assignments: SeatAssignment.seating_as_list(order_uuid, [SeatAssignment::TEMPORARY, SeatAssignment::ASSIGNED]),
                         ticket_count: current_assignment_count(order_uuid) }
        end
      end
    end
  end

  def release
    respond_to do |format|
      format.html do
        raise 'Action not allowed'
      end
      format.json do
        order_uuid = params[:order_uuid]
        sa = SeatAssignment.find(params[:id])
        reseating = params[:reseating]
        released_ticket_class_id = sa.ticket_class_id
        SeatAssignment.transaction do
          if reseating.nil?
            if sa.assigned?(order_uuid)
              destroy_ticket_line_item_for(sa)
              sa.unassign_from_order(order_uuid)
              sa.update(price_override: nil)
            end
          elsif sa.assigned?(order_uuid)
            sa.begin_release_from_order(order_uuid)
          end
        end
        status = view_context.assignment_keys(sa, order_uuid)
        render json: { id: sa.id, status: status, order_uuid: sa.order_uuid,
                       current_seat_assignments: SeatAssignment.seating_as_list(order_uuid, [SeatAssignment::TEMPORARY, SeatAssignment::ASSIGNED]),
                       ticket_class_id: released_ticket_class_id, unavailable: unavailable_seating_report(order_uuid, sa.performance_id),
                       ticket_count: current_assignment_count(order_uuid) }
      end
    end
  end

  def update_price_override
    respond_to do |format|
      format.json do
        order_uuid = params[:order_uuid]
        sa = SeatAssignment.find(params[:id])
        price_override = parse_price_override(params[:price_override], sa.ticket_class_id)
        unless sa.assigned?(order_uuid)
          render json: { status: 'error', message: 'Seat is not assigned to this order' }, status: :unprocessable_entity
          return
        end
        unless sa.ticket_class&.ticket_type == TicketClass::DONATION
          render json: { status: 'error', message: 'Price override only allowed on donation ticket classes' },
                 status: :unprocessable_entity
          return
        end
        SeatAssignment.transaction do
          sa.update(price_override: price_override)
          tli = sa.ticket_line_item
          tli.update(price_override: price_override) if tli
        end
        render json: { id: sa.id, price_override: sa.price_override, ticket_class_id: sa.ticket_class_id }
      end
    end
  end

  def release_temporary
    respond_to do |format|
      format.html do
        raise 'Action not allowed'
      end
      format.json do
        order_uuid = params[:order_uuid]
        SeatAssignment.where('order_uuid = :order_uuid and status = :temp_assignment and performance_id <> :performance_id',
                             order_uuid: order_uuid, temp_assignment: SeatAssignment::TEMPORARY,
                             performance_id: params['exclude_performance_id'].to_i).update_all(order_uuid: nil, updated_at: Time.now, status: SeatAssignment::AVAILABLE)
        render json: { status: 'released' }
      end
    end
  end

  def commit_reseating
    respond_to do |format|
      format.html do
        raise 'Action not allowed'
      end
      format.json do
        order_uuid = params[:order_uuid]
        result = SeatAssignment.reseating_commit(order_uuid)
        render json: { status: result,
                       current_seat_assignments: SeatAssignment.seating_as_list(order_uuid,
                                                                                [SeatAssignment::TEMPORARY,
                                                                                 SeatAssignment::ASSIGNED]) }
      end
    end
  end

  def rollback_reseating
    respond_to do |format|
      format.html do
        raise 'Action not allowed'
      end
      format.json do
        order_uuid = params[:order_uuid]
        SeatAssignment.reseating_rollback(order_uuid)
        render json: { status: 'success' }
      end
    end
  end

  def unavailable_seating_report(order_uuid, performance_id)
    SeatAssignment.where(
      'performance_id = :performance_id and order_uuid <> :order_uuid and status not in(:available_status)',
      performance_id: performance_id,
      order_uuid: order_uuid,
      available_status: SeatAssignment::AVAILABLE
    ).all.map do |sa|
      sa.id
    end
  end

  protected

  def current_assignment_count(order_uuid, exclude_sa_id = nil)
    SeatAssignment.current_seat_assignments(order_uuid, exclude_sa_id).count
  end

  private

  # Returns a BigDecimal price override, or nil when the caller didn't send one
  # or the referenced ticket class isn't a Donation class.
  def parse_price_override(raw, ticket_class_id)
    return nil if raw.nil? || raw.to_s.strip.empty?

    tc = TicketClass.find_by(id: ticket_class_id)
    return nil unless tc&.ticket_type == TicketClass::DONATION

    value = BigDecimal(raw.to_s)
    value.positive? ? value : nil
  rescue ArgumentError
    nil
  end

  # When an Order record already exists for the seat's order_uuid (admin editing
  # a saved reserved-seat order), create or update the 1:1 TicketLineItem to
  # match the SeatAssignment. For new-order checkout the Order does not yet
  # exist, so we skip — the per-seat TLI is built from nested form attributes
  # when the order is submitted.
  def upsert_ticket_line_item_for(sa, order_uuid, price_override)
    return if sa.ticket_class_id.to_i.zero?

    order = Order.find_by(uuid: order_uuid)
    return unless order.is_a?(TicketOrder) && order.persisted?

    tli = order.ticket_line_items.find_by(seat_assignment_id: sa.id) ||
          order.ticket_line_items.build(seat_assignment_id: sa.id)
    tli.ticket_class_id = sa.ticket_class_id
    tli.ticket_count = 1
    tli.price_override = price_override
    tli.save!
    tli.id
  end

  def destroy_ticket_line_item_for(sa)
    tli = sa.ticket_line_item
    tli&.destroy
  end

  def load_performance_and_seat_assignments
    @performance = Performance.find(params[:performance_id])
    @seat_assignments = SeatAssignment.joins(:seat).where(performance_id: @performance.id)
    if @seat_assignments.empty? and !@performance.production.seat_map.nil?
      @seat_assignments = @performance.production.seat_map.create_inventory_for_performance(@performance)
    end
    @seat_assignments.order(:originY, :originX)
  end
end
