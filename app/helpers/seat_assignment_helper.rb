module SeatAssignmentHelper
  def assignment_keys(sa, order_uuid)
    if sa.releasing?(order_uuid)
      'releasing'
    elsif sa.assigned?(order_uuid)
      'assigned'
    else
      (sa.available? ? 'available' : 'unavailable')
    end
  end
end
