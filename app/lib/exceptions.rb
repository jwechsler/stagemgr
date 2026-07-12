module Exceptions
  # Order exceptions
  class TooManyTicketsForMembership < StandardError; end

  class RepeatVisitsAtDoorOnly < StandardError; end

  class FestivalTicketsAtDoorOnly < StandardError; end

  class PassAlreadyUsedThisWeek < StandardError; end

  class PerformanceOutsideCurrentWeek < StandardError; end

  # Membership exceptions
  class UnknownMembershipCode < StandardError; end

  # seating exceptions
  class SeatUnavailableError < StandardError; end

  class SeatingNotAllowedForProduction < StandardError; end
end
