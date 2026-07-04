# Zoned pricing: the single source of truth for zone formats and the
# class-zone/seat-zone match rule. Every enforcement point (ticket class
# selector, reserve, SeatManagementService, reseating) calls match? so the
# rule can never drift between code paths.
#
# Seats carry a 1-2 char [A-Z0-9] zone (default "A", never "*").
# Ticket classes carry the same format OR the wildcard "*" (default),
# which matches any seat zone.
module ZoneMatchable
  WILDCARD = '*'.freeze
  SEAT_ZONE_FORMAT = /\A[A-Z0-9]{1,2}\z/
  CLASS_ZONE_FORMAT = /\A(\*|[A-Z0-9]{1,2})\z/

  def self.match?(class_zone, seat_zone)
    class_zone == WILDCARD || class_zone == seat_zone
  end
end
