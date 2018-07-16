class SeatAssignment < ActiveRecord::Base
  
  belongs_to :order
  belongs_to :seat_map
  belongs_to :seat
  belongs_to :performance

  SEAT_STATUSES = (
  AVAILABLE, ASSIGNED, TEMPORARY, BROKEN =
      "Available", "Assigned", "Held", "N/A")
  
  def available?
    status.eql?(AVAILABLE)
  end
  
end
