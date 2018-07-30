class SeatAssignment < ActiveRecord::Base

  belongs_to :order
  belongs_to :seat_map
  belongs_to :seat
  belongs_to :performance

  SEAT_STATUSES = (
  AVAILABLE, ASSIGNED, TEMPORARY, BROKEN =
      "Available", "Assigned", "Held", "N/A")

  def available?(check_order=nil)
    a = status.eql?(AVAILABLE)
    a ||= assigned?(check_order) unless check_order.nil?
    a
  end

  def assigned?(check_order)
    (status.eql?(TEMPORARY) || status.eql?(ASSIGNED)) && order_id.eql?(check_order.id)
  end

  def temporary?
    status.eql?(TEMPORARY)
  end

  def self.available_seat_assignments(performance, order)
    if performance.seat_assignments.empty? and performance.production.has_reserved_seating? then
      performance.seat_assignments << performance.production.seat_map.create_inventory_for_performance(performance)
      Rails.logger.debug ("assigned inventory")
    end
    performance.seat_assignments
  end

  def unassign_from_order!(ticket_order)
    if seat.order_id.eql?(ticket_order.id)
      seat.order_id = nil
      seat.status = SeatAssignment::AVAILABLE
      seat.save!
    end
  end

end
