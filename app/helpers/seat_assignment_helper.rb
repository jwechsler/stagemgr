module SeatAssignmentHelper

  def assignment_keys(sa, order_uuid)
    keys = sa.releasing?(order_uuid) ? 'releasing' : sa.assigned?(order_uuid) ? 'assigned' : (sa.available? ? 'available' : 'unavailable')
    keys
  end

end
