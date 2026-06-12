class SeatManagementService
  attr_reader :performance, :order_uuid

  def initialize(performance, order_uuid = nil)
    @performance = performance
    @order_uuid = order_uuid
  end

  # Assigns seats to an order
  # @param seats [Array<Integer>] Array of seat IDs to assign
  # @param ticket_class_id [Integer] The ticket class ID for these seats
  # @param accessibility [String, nil] Any accessibility requirements
  # @return [Result] Success/failure with assigned seats or error message
  def assign_seats(seats, ticket_class_id, accessibility = nil)
    Result.new.tap do |result|
      return result.fail!("No seats specified") if seats.empty?
      return result.fail!("Invalid ticket class") unless valid_ticket_class?(ticket_class_id)

      begin
        ActiveRecord::Base.transaction do
          assignments = find_available_seats(seats)
          validate_seat_assignments!(assignments)

          assigned = assign_seats_to_order(assignments, ticket_class_id, accessibility)
          first_assignment = assigned.first

          result.success!({
                            id: first_assignment.id,
                            status: first_assignment.status,
                            order_uuid: first_assignment.order_uuid,
                            current_seat_assignments: SeatAssignment.seating_as_list(order_uuid,
                                                                                     [SeatAssignment::TEMPORARY, SeatAssignment::ASSIGNED]),
                            unavailable: unavailable_seating_report(order_uuid, performance.id),
                            ticket_count: current_assignment_count(order_uuid)
                          })
        end
      rescue SeatError => e
        result.fail!(e.message)
      end
    end
  end

  # Releases seats from an order
  # @param seats [Array<Integer>] Array of seat IDs to release
  # @return [Result] Success/failure with released seats or error message
  def release_seats(seats)
    Result.new.tap do |result|
      return result.fail!("No seats specified") if seats.empty?

      begin
        ActiveRecord::Base.transaction do
          assignments = find_order_seats(seats)
          validate_release!(assignments)

          puts "Comparing order UUIDs: #{assignments.map(&:order_uuid)} with #{order_uuid}"

          released = release_seats_from_order(assignments)
          first_assignment = released.first

          result.success!({
                            id: first_assignment.id,
                            status: first_assignment.status,
                            order_uuid: first_assignment.order_uuid,
                            current_seat_assignments: SeatAssignment.seating_as_list(order_uuid,
                                                                                     [SeatAssignment::TEMPORARY, SeatAssignment::ASSIGNED]),
                            ticket_class_id: first_assignment.ticket_class_id,
                            unavailable: unavailable_seating_report(order_uuid, performance.id),
                            ticket_count: current_assignment_count(order_uuid)
                          })
        end
      rescue SeatError => e
        result.fail!(e.message)
      end
    end
  end

  # Confirms temporary seat assignments for an order
  # @return [Result] Success/failure with confirmed seats or error message
  def confirm_seat_assignments
    Result.new.tap do |result|
      begin
        ActiveRecord::Base.transaction do
          assignments = find_temporary_assignments
          validate_confirmation!(assignments)

          confirmed = confirm_assignments(assignments)
          result.success!({
                            status: SeatAssignment::ASSIGNED,
                            current_seat_assignments: SeatAssignment.seating_as_list(order_uuid,
                                                                                     [SeatAssignment::TEMPORARY, SeatAssignment::ASSIGNED])
                          })
        end
      rescue SeatError => e
        result.fail!(e.message)
      end
    end
  end

  # Begins reseating process for a seat
  # @param seat_id [Integer] ID of the seat to reseat
  # @return [Result] Success/failure with reseating status or error message
  def begin_reseating(seat_id)
    Result.new.tap do |result|
      begin
        ActiveRecord::Base.transaction do
          assignment = SeatAssignment.find(seat_id)

          if assignment.assigned?(order_uuid)
            assignment.begin_release_from_order(order_uuid)
            status = assignment.status

            result.success!({
                              id: assignment.id,
                              status: status,
                              order_uuid: assignment.order_uuid,
                              current_seat_assignments: SeatAssignment.seating_as_list(order_uuid,
                                                                                       [SeatAssignment::TEMPORARY, SeatAssignment::ASSIGNED]),
                              ticket_class_id: assignment.ticket_class_id,
                              unavailable: unavailable_seating_report(order_uuid, performance.id),
                              ticket_count: current_assignment_count(order_uuid)
                            })
          else
            result.fail!("Seat is not assigned to this order")
          end
        end
      rescue ActiveRecord::RecordNotFound
        result.fail!("Seat assignment not found")
      rescue => e
        result.fail!(e.message)
      end
    end
  end

  private

  def find_available_seats(seat_ids)
    SeatAssignment.where(
      seat_id: seat_ids,
      performance_id: performance.id
    ).select { |assignment| assignment.available?(order_uuid) }
  end

  def find_order_seats(seat_ids)
    SeatAssignment.where(
      seat_id: seat_ids,
      performance_id: performance.id
    )
  end

  def find_temporary_assignments
    SeatAssignment.where(
      performance_id: performance.id,
      order_uuid: order_uuid,
      status: SeatAssignment::TEMPORARY
    )
  end

  def validate_seat_assignments!(assignments)
    raise SeatError, "Some seats are not available" if assignments.empty?
    raise SeatError, "Seat limit exceeded" if exceeds_seat_limit?(assignments.size)
  end

  def validate_release!(assignments)
    raise SeatError, "No matching seats found for release" if assignments.empty?
    raise SeatError, "Cannot release seats from different order" unless assignments.all? { |a|
      a.order_uuid == order_uuid
    }
  end

  def validate_confirmation!(assignments)
    raise SeatError, "No temporary seats found to confirm" if assignments.empty?

    order = Order.find_by(uuid: order_uuid)
    raise SeatError, "Order not found" unless order
    raise SeatError, "Seat count mismatch" unless assignments.size == order.number_of_tickets
  end

  def assign_seats_to_order(assignments, ticket_class_id, accessibility)
    assignments.each do |assignment|
      assignment.assign_to_order(order_uuid, assignments.size, ticket_class_id, accessibility)
    end
    assignments
  end

  def release_seats_from_order(assignments)
    assignments.each do |assignment|
      assignment.begin_release_from_order(order_uuid)
    end
    assignments
  end

  def confirm_assignments(assignments)
    assignments.update_all(
      status: SeatAssignment::ASSIGNED,
      updated_at: Time.current
    )
    assignments
  end

  def valid_ticket_class?(ticket_class_id)
    return false unless ticket_class_id

    performance.ticket_classes.exists?(ticket_class_id)
  end

  def exceeds_seat_limit?(requested_count)
    current_count = SeatAssignment.where(
      status: [SeatAssignment::TEMPORARY, SeatAssignment::ASSIGNED],
      order_uuid: order_uuid
    ).count

    (current_count + requested_count) > performance.production.capacity
  end

  def unavailable_seating_report(order_uuid, performance_id)
    SeatAssignment.where(
      "performance_id = :performance_id and order_uuid <> :order_uuid and status not in(:available_status)",
      performance_id: performance_id,
      order_uuid: order_uuid,
      available_status: SeatAssignment::AVAILABLE
    ).pluck(:id)
  end

  def current_assignment_count(order_uuid, exclude_sa_id = nil)
    query = SeatAssignment.where(order_uuid: order_uuid)
    query = query.where.not(id: exclude_sa_id) if exclude_sa_id
    query.count
  end

  class Result
    attr_reader :success, :data, :error

    def initialize
      @success = false
      @data = nil
      @error = nil
    end

    def success!(data = nil)
      @success = true
      @data = data
      self
    end

    def fail!(error)
      @success = false
      @error = error
      self
    end

    def success?
      @success
    end

    def failure?
      !@success
    end
  end

  class SeatError < StandardError; end
end
