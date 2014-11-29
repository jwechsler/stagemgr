class HouseManagementReport < Report

  attr_accessor :for_date

  def initialize(for_date, reporting_user_id = nil)
    super(reporting_user_id)
    self.for_date = for_date
  end

  def self.ticket_orders(for_date)
    TicketOrder.includes(:address, {:performance=>:production}).where(
      "performances.performance_date = :performance_date and orders.status in (:attending)",
      {:performance_date=>for_date, :attending=>Order.attending_statuses + Order.held_statuses}).
      order('productions.venue_id, performances.performance_time, addresses.last_name, addresses.first_name')
  end

  def ticket_orders
    HouseManagementReport.ticket_orders(self.for_date)
  end

  def create
    orders = self.ticket_orders
    report = Array.new
    headers = [:production_name, :performance_code, :patron_name, :seats, :special_requests, :notes, :is_member, :is_donor]
    orders.each do |o|
      if !o.special_request.blank? || !o.notes.blank? || o.address.is_current_member? || o.address.is_donor? || !o.address.address_tags.empty?
        note_column = o.notes.blank? ? "" : o.notes
        unless o.address.address_tags.empty?
          note_column += "<br/>" unless note_column.blank?
          note_column += "Patron Notes: " + o.address.address_tags.map{|tag|
            r = "<i><font size=\"-1\" >#{tag.tag_label}"
            r += " [#{tag.theater.name}]" unless (tag.theater_id.nil? || tag.theater.is_default?)
            r += " (#{tag.tag_value})" unless tag.tag_value.blank?
            r += "</font></i>"
            r
          }.join(", ")
        end
        report << {
          :production_name => o.performance.production.name,
          :patron_name => o.address.full_name,
          :performance_code => o.performance.performance_code,
          :special_requests =>  (o.special_request.blank? ? nil : o.special_request) || (o.address.is_current_member? ? o.address.current_membership.preferred_seating : ''),
          :notes => note_column,
          :is_member => o.address.is_current_member?,
          :is_donor => ((o.address.donated_last_n_days || 0) == 0) ? nil : o.address.donated_last_n_days,
          :seats => o.number_of_seats
        }
      end
    end

    [headers, report]
  end

end
