# How patrons holding a ticket of this class attend the performance. Shared by
# TicketClass, DefaultTicketClass (DefaultTicketClass#to_hash copies the string
# verbatim onto new productions) and ResourcedTicketClass (shadow_attributes
# copies it onto every shadow row).
#
# - in_person (default): a physical visit; the only mode that prints a ticket.
#   Add-ons used at the venue (drink vouchers) are in_person classes that don't
#   hold seats: they print but aren't counted as tickets.
# - virtual: streaming access; no printed ticket, no visit/pickup email copy
# - other: not a ticket for the patron (e.g. a tablet reservation the house
#   handles); never prints and never counts toward any ticket total
module TicketAdmission
  extend ActiveSupport::Concern

  ADMISSIONS = { in_person: 'in_person', virtual: 'virtual', other: 'other' }.freeze

  included do
    enum admission: ADMISSIONS, _prefix: true
  end

  def prints_ticket?
    admission_in_person?
  end
end
