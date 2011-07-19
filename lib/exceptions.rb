module Exceptions
  # Order exceptions
  class TooManyTicketsForMembership < StandardError; end

  # Membership exceptions
  class UnknownMembershipCode < StandardError; end


end