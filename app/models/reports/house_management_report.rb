class HouseManagementReport < Report
  attr_accessor :for_date

  def initialize(for_date, reporting_user_id = nil)
    super(reporting_user_id)
    self.for_date = for_date
  end

  def self.ticket_orders(for_date)
    TicketOrder.includes(:address, { :performance => :production }).where(
      "performances.performance_date = :performance_date and orders.status in (:attending)",
      { :performance_date => for_date, :attending => (Order::FINALIZED_STATUSES + Order::HELD_STATUSES) }
    )
               .order('productions.venue_id, performances.performance_time, addresses.last_name, addresses.first_name')
  end

  def ticket_orders
    HouseManagementReport.ticket_orders(self.for_date)
  end

  def house_tags(address)
    unless address.nil?
      address.address_tags.select do |tag|
        next false if tag.tag_label == AddressTag::EXTERNAL_ID

        tag.theater_id.blank? || tag.theater.producing?
      end
    else
      Array.new
    end
  end

  def visits_by_address(address_ids)
    return {} if address_ids.empty?

    scope = TicketOrder.attending.joins(:performance)
                       .where(address_id: address_ids)
                       .where("performances.performance_date <= ?", self.for_date)
    range_days = $SERVER_CONFIG['report_frequent_customer_range_days']
    scope = scope.where("performances.performance_date >= ?", self.for_date - range_days.to_i) if range_days
    scope.group(:address_id).count
  end

  def frequent_customer_threshold
    $SERVER_CONFIG['report_frequent_customer_at']
  end

  def create
    orders = self.ticket_orders
    report = Array.new
    headers = [:production_name, :performance_code, :patron_name, :seats, :special_requests, :notes, :is_member,
               :is_donor, :visits, :photo]
    visit_counts = visits_by_address(orders.map(&:address_id).uniq)
    threshold = frequent_customer_threshold
    orders.each do |o|
      seat_assignments = o.seat_assignments
      print_tags = house_tags(o.address)
      visit_count = visit_counts[o.address_id] || 0
      frequent_attendee = threshold && visit_count >= threshold.to_i
      if !o.special_request.blank? || !o.notes.blank? || o.address.is_current_member? || o.address.is_donor? || !print_tags.empty? || o.assigned_seats? || o.address.photo.attached? || o.address.vip? || frequent_attendee
        note_column = o.address.vip? ? "VIP" : ""
        unless o.notes.blank?
          note_column += "<br/>" unless note_column.blank?
          note_column += o.notes
        end
        unless print_tags.empty?
          note_column += "<br/>" unless note_column.blank?
          note_column += "Patron Notes: " + print_tags.map { |tag|
            r = "<i><font size=\"-1\" >#{tag.tag_label}"
            r += " [#{tag.theater.name}]" unless (tag.theater_id.nil? || tag.theater.producing?)
            r += " (#{tag.tag_value})" unless tag.tag_value.blank?
            r += "</font></i>"
            r
          }.join(", ")
        end
        unless seat_assignments.blank?
          note_column += "<br/>" unless note_column.blank?
          note_column += "Seating: <i><font size=\"-1\" >#{seat_assignments}</font></i>"
        end

        report << {
          :production_name => o.performance.production.name,
          :patron_name => o.address.full_name,
          :performance_code => o.performance.performance_code,
          :special_requests => (o.special_request.blank? ? nil : o.special_request) || (o.address.is_current_member? ? o.address.current_membership.preferred_seating : ''),
          :notes => note_column,
          :is_member => o.address.is_current_member?,
          :is_donor => o.address.is_donor? ? o.address.most_recent_donation_tier : "",
          :seats => o.number_of_seats,
          :visits => visit_count,
          :photo => o.address.photo
        }
      end
    end

    [headers, report]
  end
end
