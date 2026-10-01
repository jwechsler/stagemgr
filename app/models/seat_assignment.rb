class SeatAssignment < ApplicationRecord
  before_destroy :verify_unused

  belongs_to :order, foreign_key: :order_uuid, primary_key: :uuid, optional: true, inverse_of: :seats
  belongs_to :seat, inverse_of: :seat_assignments
  belongs_to :performance, inverse_of: :seat_assignments
  belongs_to :ticket_class, optional: true
  has_one :ticket_line_item, inverse_of: :seat_assignment

  SEAT_STATUSES = (
  AVAILABLE, ASSIGNED, TEMPORARY, RELEASING, BROKEN =
    "Available", "Assigned", "Held", "Releasing", "N/A")

  # NOTE: this "available" is a PER-SEAT reserved-seating concept and is unrelated
  # to Performance#seats_available / HouseCount#available_seats (which are aggregate
  # seat counts) or to Order::ON_HOLD_STATUSES. Here a seat is available when it is
  # unassigned (AVAILABLE) -- or, when a specific order's UUID is supplied, when it
  # is already assigned to that same order (so a buyer can keep their own seats).
  def available?(check_order_uuid = nil)
    a = status.eql?(AVAILABLE)
    a ||= assigned?(check_order_uuid) unless check_order_uuid.nil?
    a
  end

  def assigned?(check_order_uuid = nil)
    use_uuid = check_order_uuid || order_uuid
    !use_uuid.nil? && [TEMPORARY, ASSIGNED, RELEASING].include?(status) && order_uuid.eql?(check_order_uuid)
  end

  def temporary?
    status.eql?(TEMPORARY)
  end

  def releasing?(check_order_uuid)
    status.eql?(RELEASING) && assigned?(check_order_uuid)
  end

  def self.available_seat_assignments(performance, order = nil)
    if performance.seat_assignments.empty? and performance.production.has_reserved_seating? then
      performance.seat_assignments << performance.production.seat_map.create_inventory_for_performance(performance)
    end
    performance.seat_assignments
  end

  def self.seating_as_list(order_uuid, assignment_types)
    SeatAssignment.includes(:seat).where("status in (:assignment_types) and order_uuid = :order_uuid",
                                         order_uuid: order_uuid,
                                         assignment_types: assignment_types).all.map { |sa| sa.seat.location }.sort.join(", ")
  end

  # Proxy for seat location
  #
  def location; end

  def assign_to_order(order_uuid, limit_seats = 999, ticket_class_id = nil, accessibility = nil)
    number_assigned = SeatAssignment.where(status: [SeatAssignment::TEMPORARY, SeatAssignment::ASSIGNED],
                                           order_uuid: order_uuid).size
    unless number_assigned >= limit_seats
      SeatAssignment.where("id = :id and (order_uuid is null or order_uuid = '' or order_uuid = :order_uuid)", id: id, order_uuid: order_uuid).update_all(
        order_uuid: order_uuid, ticket_class_id: ticket_class_id, updated_at: Time.now, status: SeatAssignment::TEMPORARY, accessibility: accessibility
      )
      reload
    end
    (self.order_uuid == order_uuid)
  end

  def begin_release_from_order(order_uuid)
    self.status = RELEASING
    save!
  end

  # Zoned pricing: before a reseat is finalized, every ticket class being
  # released must be placeable on a distinct newly-held seat whose zone it
  # matches. Specific-zone classes can only take seats in their own zone;
  # wildcard ("*") classes take anything, so feasibility reduces to a per-zone
  # count check. Returns nil when feasible, or a human-readable conflict.
  def self.reseating_zone_conflict(order_uuid)
    # Same per-seat class SeatReseat pairs with: the linked line item's, else the seat's.
    release_classes = SeatReseat.new(order_uuid).release_classes
    return nil if release_classes.empty?

    incoming_zone_counts = where(order_uuid: order_uuid, status: TEMPORARY)
                           .includes(:seat).map { |sa| sa.seat.zone }.tally

    specific = release_classes.compact
                              .reject { |tc| tc.zone_id == ZoneMatchable::WILDCARD }
    specific.group_by(&:zone_id).each do |zone, classes|
      next if classes.size <= (incoming_zone_counts[zone] || 0)

      return "Not enough seats selected in zone #{zone} for " \
             "#{classes.map(&:class_name).uniq.join(', ')}"
    end
    nil
  end

  def self.reseating_commit(order_uuid)
    o = Order.find_by(uuid: order_uuid)
    # Compare against seat-holding tickets only — number_of_tickets would also
    # count non-seat (holds_seats=false) tickets and make mixed orders
    # impossible to reseat.
    if SeatAssignment.current_seat_assignments(o.uuid).count.eql?(o.number_of_seats)
      conflict = reseating_zone_conflict(order_uuid)
      return conflict unless conflict.nil?

      SeatAssignment.transaction do
        # Move line items, class, price and order id onto the new seats first.
        unmatched = SeatReseat.new(order_uuid).apply!
        if unmatched
          conflict = unmatched
          raise ActiveRecord::Rollback
        end

        SeatAssignment.where(order_uuid: order_uuid, status: SeatAssignment::TEMPORARY).update_all(
          status: SeatAssignment::ASSIGNED, updated_at: Time.now
        )
        # A released seat keeps nothing of the order: a stale order_id or class
        # would otherwise survive into its next sale.
        SeatAssignment.where(order_uuid: order_uuid, status: SeatAssignment::RELEASING).update_all(
          status: SeatAssignment::AVAILABLE, order_uuid: nil, order_id: nil, ticket_class_id: nil,
          price_override: nil, accessibility: nil, updated_at: Time.now
        )
      end
      conflict || "success"
    else
      Rails.logger.debug("Mismatched seats for order #{o.id}")
      "failure"
    end
  end

  def self.reseating_rollback(order_uuid)
    SeatAssignment.transaction do
      SeatAssignment.where(order_uuid: order_uuid, status: SeatAssignment::RELEASING).update_all(
        status: SeatAssignment::ASSIGNED, updated_at: Time.now
      )
      SeatAssignment.where(order_uuid: order_uuid, status: SeatAssignment::TEMPORARY).update_all(
        status: SeatAssignment::AVAILABLE, order_uuid: nil, updated_at: Time.now, accessibility: nil
      )
    end
  end

  def self.assign_seats_to_saved_order(order_uuid)
    order = Order.find_by(uuid: order_uuid)
    return if order.nil?
      SeatAssignment.where('order_uuid = :order_uuid and status = :temp_status', order_uuid: order_uuid, temp_status: SeatAssignment::TEMPORARY).update_all(
        status: ASSIGNED, updated_at: Time.now, order_id: order.id
      )
    
  end

  # Expired TEMPORARY holds are released when no order owns them yet, or when
  # the owning order is already settled. A settled order holds TEMPORARY seats
  # only mid-way through Add to Order or Change Seating; an abandoned pick
  # there would otherwise sit forever, then be swept into the order by the next
  # save (TicketOrder#finalize_seat_assignments) with no line item behind it.
  # A settled order's hold that already has a line item is left alone: it is
  # paid for (legacy side-door edits), and freeing it would let it be resold.
  def self.release_expired_temporary_holds
    results = SeatAssignment.where(
      "updated_at < :expire_time and status = :temp_status and " \
      "(order_uuid is null or not exists (select * from orders where uuid=order_uuid) " \
      "or (exists (select * from orders where uuid = order_uuid and status in (:settled_statuses)) " \
      "and not exists (select * from line_items where line_items.seat_assignment_id = seat_assignments.id)))",
      expire_time: Time.now - Rails.configuration.x.server_config['order_expiration_in_minutes'].to_i.minutes,
      temp_status: SeatAssignment::TEMPORARY,
      settled_statuses: Order::SETTLED_STATUSES
    )
    count = release_seat_assignments(results)
    Rails.logger.info("Released #{count} expired seat assignments") unless count.zero?
    count
  end

  def self.release_temporary_holds_for_performance(performance_id)
    # Find TEMPORARY seats for this performance that either:
    # - Have no order_uuid, OR
    # - The order no longer exists, OR
    # - The order is not in a holding status
    results = SeatAssignment.where(
      "performance_id = :performance_id and status = :temp_status and " \
      "(order_uuid is null or " \
      "not exists (select * from orders where uuid = seat_assignments.order_uuid and status in (:holding_statuses)))",
      performance_id: performance_id,
      temp_status: SeatAssignment::TEMPORARY,
      holding_statuses: Order::HOLDING_SEAT_STATUSES
    )
    count = release_seat_assignments(results)
    Rails.logger.info("Released #{count} temporary holds for performance #{performance_id}") unless count.zero?
    count
  end

  def unassign_from_order(ticket_order_uuid)
    if order_uuid.eql?(ticket_order_uuid)
      self.order_id = nil
      self.order_uuid = nil
      self.status = SeatAssignment::AVAILABLE
      self.accessibility = nil
      save
    end
    order_uuid.nil? || (order_uuid != ticket_order_uuid)
  end

  def self.current_seat_assignments(order_uuid, exclude_sa_id = nil)
    if exclude_sa_id.nil?
      SeatAssignment.where("status in (:assigned_statuses) and order_uuid = :uuid",
                           assigned_statuses: [SeatAssignment::ASSIGNED, SeatAssignment::TEMPORARY],
                           uuid: order_uuid)
    else
      SeatAssignment.where("status in (:assigned_statuses) and order_uuid = :uuid and id <> :sa_id",
                           assigned_statuses: [SeatAssignment::ASSIGNED, SeatAssignment::TEMPORARY],
                           uuid: order_uuid,
                           sa_id: exclude_sa_id)
    end
  end

  private

  def self.release_seat_assignments(seat_assignments)
    count = 0
    SeatAssignment.transaction do
      seat_assignments.each do |sa|
        sa.order_uuid = nil
        sa.accessibility = nil
        sa.status = SeatAssignment::AVAILABLE
        sa.save!
        count += 1
      end
    end
    count
  end

  def verify_unused
    order_uuid.blank?
  end
end
