# How a TicketOrder's patrons attend, derived from each line's ticket class
# admission mode (see TicketAdmission). Drives printing (only in_person tickets
# print) and the visit/pickup copy in patron emails.
module TicketOrderAdmission
  extend ActiveSupport::Concern

  # Tickets (not seats) in classes of the given admission mode
  # ('in_person', 'virtual' or 'other').
  def admission_ticket_count(mode)
    ticket_line_items.select { |li| li.ticket_class&.admission == mode.to_s }
                     .sum { |li| li.ticket_count.to_i }
  end

  # Tickets that admit someone to the performance: seat-holding in_person
  # tickets plus virtual ones. In-person classes that don't hold seats are
  # add-ons (drink vouchers) and 'other' classes are not tickets at all, so
  # neither counts. The ticket total in patron emails.
  def attending_ticket_count
    box_office_ticket_count + admission_ticket_count('virtual')
  end

  # In-person tickets that hold seats: what waits at the box office for pickup.
  def box_office_ticket_count
    ticket_line_items.select { |li| li.ticket_class&.admission_in_person? && li.ticket_class.holds_seats? }
                     .sum { |li| li.ticket_count.to_i }
  end

  def attends_in_person?
    admission_ticket_count('in_person').positive?
  end

  def includes_virtual?
    admission_ticket_count('virtual').positive?
  end

  # PrintBatchJob fulfills orders without any (e.g. streaming-only) without
  # sending them to tktprint.
  def contains_printable_tickets?
    attends_in_person?
  end
end
