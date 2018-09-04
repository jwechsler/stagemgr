class SeatAssignment < ActiveRecord::Base

  belongs_to :order
  belongs_to :seat_map
  belongs_to :seat
  belongs_to :performance
  validates_presence_of :order, :if=>:assigned?
  SEAT_STATUSES = (
  AVAILABLE, ASSIGNED, TEMPORARY, BROKEN =
      "Available", "Assigned", "Held", "N/A")

  def available?(check_order=nil)
    a = status.eql?(AVAILABLE)
    a ||= assigned?(check_order) unless check_order.nil?
    a
  end

  def assigned?(check_order = nil)
    (status.eql?(TEMPORARY) || status.eql?(ASSIGNED)) && (check_order.nil? ? !self.order_id.nil? : order_id.eql?(check_order.id))
  end

  def temporary?
    status.eql?(TEMPORARY)
  end

  def self.available_seat_assignments(performance, order)
    if performance.seat_assignments.empty? and performance.production.has_reserved_seating? then
      performance.seat_assignments << performance.production.seat_map.create_inventory_for_performance(performance)
    end
    performance.seat_assignments
  end

  def assign_to_order(order)
    number_assigned = SeatAssignment.where(status: [SeatAssignment::TEMPORARY, SeatAssignment::ASSIGNED], order_id:order.id).size
    unless number_assigned >= order.number_of_seats
      SeatAssignment.where("id = :id and (order_id is null or order_id = :order_id)",id:self.id, order_id: order.id).update_all(order_id: order.id, status: SeatAssignment::ASSIGNED)
      self.reload
    end
    (self.order_id == order.id)
  end

  def unassign_from_order(ticket_order)
    if self.order_id.eql?(ticket_order.id)
      self.order_id = nil
      self.status = SeatAssignment::AVAILABLE
      self.save
    end
  end

end
