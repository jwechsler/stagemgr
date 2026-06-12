class OrderReport < Report
  def self.columns_for_orders(build_for_dumpfile = true, include_emails = false)
    keys = [:order_date]
    if build_for_dumpfile
      keys += %i[id first_name last_name street_address street_address_2 city state postal_code
                 phone]
    end
    keys += [:email] if include_emails && build_for_dumpfile
    if build_for_dumpfile
      keys += %i[performance_code special_offer_code status description facility_fee
                 processing_fee]
    end
    keys
  end

  def self.address_hash(a)
    { last_name: a.last_name,
      first_name: a.first_name,
      street_address: a.line1,
      street_address_2: a.line2,
      city: a.city,
      state: a.state,
      postal_code: a.zipcode,
      phone: a.phone,
      email: a.email,
      address_id: a.id }
  end

  def self.address_hash_from_order(o)
    if o.address.blank?
      { last_name: 'Purchaser',
        first_name: 'Unknown',
        street_address: '',
        street_address_2: '',
        city: '',
        state: '',
        postal_code: '',
        phone: '',
        email: '' }
    else
      address_hash(o.address)
    end
  end

  def self.create_hash_from_order_fields(order)
    row = {}
    row[:order_date] = order.created_at.to_formatted_s(:long) unless order.created_at.nil?
    row[:id] = order.id
    row = row.merge(address_hash_from_order(order))
    row[:performance_code] = order.performance.performance_code if order.performance.present?
    row[:special_offer_code] = order.special_offer_code_used
    row[:status] = order.status
    row[:description] = order.description
    row[:order_total] = Money.from_amount(order.total_paid)
    row[:order_revenue] =
      Money.from_amount(order.total_paid) - Money.from_amount(order.processing_fee) - Money.from_amount(order.ticketing_fee)
    row[:num_tickets] = order.is_a?(TicketOrder) ? order.number_of_tickets : 0
    row[:num_seats] = order.is_a?(TicketOrder) ? order.number_of_seats : 0
    if order.performance.present? && order.performance.production.has_reserved_seating?
      row[:seat_assignments] = order.seats.map { |sa| sa.seat.location }.sort.join(', ')
    end
    row[:facility_fee] = Money.from_amount(order.ticketing_fee)
    row[:processing_fee] = Money.from_amount(order.processing_fee)
    row
  end
end
