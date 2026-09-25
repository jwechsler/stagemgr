# How patrons holding a ticket of this class attend the performance. Shared by
# TicketClass and DefaultTicketClass (DefaultTicketClass#to_hash copies the
# string verbatim onto new productions).
#
# - in_person (default): a physical visit; the only mode that prints a ticket
# - virtual: streaming access; no printed ticket, no visit/pickup email copy
# - other: neither prints nor streams (e.g. e-ticket or add-on style classes)
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
