class ReleaseExpiredSeatAssignments
  @queue = :maintenance

  def self.perform
    SeatAssignment.release_expired_temporary_holds
  end
end
