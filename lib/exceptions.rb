module Exceptions
  # Order exceptions
  class TooManyTicketsForMembership < StandardError; end

  class RepeatVisitsAtDoorOnly < StandardError; end

  # Membership exceptions
  class UnknownMembershipCode < StandardError; end


end