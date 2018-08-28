module SeatAssignmentHelper

  def assignment_keys(sa, order)
    sa.assigned?(order) ? 'assigned' : (sa.available? ? 'available' : 'unavailable')
  end

end
