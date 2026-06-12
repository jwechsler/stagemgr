class TicketOrder < Order
  SEATING_REQUESTS = (
    WHEELCHAIR, WHEELCHAIR_TRANSFER, STAIRS =
      'Wheelchair (no transfer)', 'Wheelchair (can transfer)', 'No stairs')

  before_validation :set_tickets_for_pass_redemption
  before_validation :unassign_seats_when_performance_changes, if: :performance_id_changed?
  after_validation do
    if status_changed? && (refunded? || unclaimed?) && performance.production.has_reserved_seating?
      unassign_seats
    end
  end

  before_save :set_theater
  before_save :remove_empty_ticket_lines

  after_save :finalize_seat_assignments
  after_save :sync_reserved_seat_price_overrides
  after_save :update_attendance_record

  before_destroy :unassign_seats
  before_destroy :reverse_source_exchange_payments, if: :exchanging?

  attr_accessor :selected_production

  has_many :ticket_line_items, :foreign_key => :order_id, inverse_of: :ticket_order
  belongs_to :exchange_source, class_name: "TicketOrder", foreign_key: "exchange_source_id", optional: true
  belongs_to :split_source, class_name: "TicketOrder", foreign_key: "split_source_id", optional: true
  delegate :production, to: :performance
  accepts_nested_attributes_for :ticket_line_items, allow_destroy: true

  validates_associated :ticket_line_items
  validates_presence_of :performance
  validate :ticket_stock_available, :unless => :allow_deletion?
  validate :seat_assignments_complete?, :if => :seating_check_required?
  validate :payments_exist?, :if => :processed?
  validates :uuid, presence: true

  validates_each :status do |record, _attr, value|
    unless record.allow_deletion?
      if value == PROCESSED
        unless record.ticket_line_items.empty? || record.number_of_tickets > 0
          record.errors.add(:ticket_line_items, "must contain at least one ticket.")
        end
        if !record.performance.nil? && record.performance.restricted_payment_types.include?(record.payment_type)
          record.errors.add(:payment_type, "is not allowed for this event")
        end
      end
    end
  end

  def ticket_stock_available
    unless ticket_line_items.empty?
      ticket_counts_by_class = Hash.new
      ticket_line_items.each do |tli|
        errors.add(:base,
                   "Missing allocation for #{performance.performance_code} / #{tli.ticket_class.nil? ? "NIL" : tli.ticket_class.class_code}") unless performance.ticket_class_allocations.map { |tla|
                                                                                                                                                            tla.ticket_class
                                                                                                                                                          }.include?(tli.ticket_class)
        if ticket_counts_by_class.key?(tli.ticket_class_id)
          ticket_counts_by_class[tli.ticket_class_id] += tli.ticket_count
        else
          ticket_counts_by_class[tli.ticket_class_id] = tli.ticket_count
        end
      end
      ticket_counts_by_class.keys.each do |key|
        allocation = TicketClassAllocation.find_by_performance_id_and_ticket_class_id(performance_id, key)
        unless allocation.nil?
          number_of_tickets_already_used = TicketLineItem.where(
            'ticket_class_id = ? and performance_id = ? and order_id != ?', key, performance_id, id
          ).joins(:order).sum(:ticket_count)
          if !allocation.ticket_limit.nil? && (ticket_counts_by_class[key] + number_of_tickets_already_used > allocation.ticket_limit) then
            remainder = allocation.ticket_limit - number_of_tickets_already_used
            if remainder > 0
              errors.add(:base,
                         "There are only #{allocation.ticket_limit - number_of_tickets_already_used} '#{TicketClass.find(key).class_name}' tickets remaining.")
            else
              errors.add(:base, "Sorry, there are no '#{TicketClass.find(key).class_name}' tickets left.")
            end
          end
        end
      end
      seats_left = performance.number_of_seats_left(self)
      errors.add(:base,
                 "There #{seats_left == 1 ? "is" : "are"} only #{seats_left} reservation#{"s" unless seats_left == 1} remaining for the #{performance.performance_date} performance at #{performance.performance_time.to_formatted_s(:standard_time)}.") if holding_seats? && seats_left < number_of_seats
    end
  end

  def payments_exist?
    !payments.empty?
  end

  def unassign_seats
    Rails.logger.info("Releasing seats for Order #{id} [#{status}] [#{seats.map { |s|
      s.seat.location
    }.join(',')}]")
    seat_ids = seats.pluck(:id)
    # Clear the seat FK on this order's TLIs so the seats can be re-sold after
    # this order is released without hitting the unique index on
    # seat_assignment_id. The TLI rows are preserved for accounting history.
    if seat_ids.any?
      TicketLineItem.where(order_id: id, seat_assignment_id: seat_ids)
                    .update_all(seat_assignment_id: nil)
    end
    seats.each { |seat| seat.unassign_from_order(uuid) }
    Rails.logger.info("Seats released for Order #{id} [#{status}] [#{seats.map { |s|
      s.seat.location
    }.join(',')}]")
  end

  def unassign_seats_when_performance_changes
    seats.reload.each { |seat|
      unless seat.performance_id.eql?(performance_id)
        seat.unassign_from_order(self)
      end
    }
    seats.reload
  end

  # def verify_fully_seated
  #   unless seat_assignments_complete?
  #     errors.add :base, "You must select #{self.number_of_seats} #{'seat'.pluralize(self.number_of_seats)} before finalizing this order"
  #   end
  # end

  def seat_assignments_complete?
    unless performance.nil?
      if number_of_tickets > 0 && performance.production.has_reserved_seating? then
        if (seats.reload.size != number_of_seats) then
          errors.add(:seats, " do not match tickets in order (#{number_of_seats} required)")
          return false
        end
        if seats.size.eql?(0) then
          errors.add(:base, "You must select at least one seat")
          return false
        end
      elsif number_of_tickets.eql?(0) then
        errors.add(:base, "You must purchase at least one ticket")
        return false
      end
    end
    true
  end

  def seatable?
    [Order::NEW, Order::PROCESSED, Order::PROCESSING, Order::EXCHANGING,
     Order::HOLD].include?(status) && performance.production.has_reserved_seating?
  end

  def theater_ids
    [performance.production.theater.id]
  end

  def self.reassign_payments(offer)
    orders = Order.where("id in (select order_id from payments where flex_pass_id in (select id from flex_passes where flex_pass_offer_id = :offer_id))",
                         { :offer_id => offer.id })

    orders.each { |o|
      was = o.to_s
      o.set_ticket_classes_using_offer(offer)
      o.save!
      if was != o.to_s
        puts "Order #{o.id}: #{was} converted to #{o}"
      else
        puts "Order #{o.id}: #{was}"
      end
    }

    nil
  end

  def contains_exchangeable_tickets?
    ticket_line_items.select { |tli| tli.ticket_class.exchangeable? }.count > 0
  end

  def exchangeable?
    status == Order::PROCESSED || status == Order::FULFILLED || status == Order::UNCLAIMED
  end

  def splittable?
    number_of_tickets > 1 && [Order::PROCESSED, Order::UNCLAIMED,
                                   Order::FULFILLED].include?(status) && !paid_with_membership?
  end

  def convertible_to_donation?
    ATTENDING_STATUSES.include?(status) &&
      paid_with_currency? &&
      theater&.accepts_donations?
  end

  def exchanged?
    status == Order::EXCHANGED
  end

  def exchanging?
    status.eql?(Order::EXCHANGING)
  end

  def split?
    status.eql?(Order::SPLIT)
  end

  def in_multi_transactional_state?
    super || [Order::RELEASING, Order::EXCHANGING].include?(status)
  end

  def refundable?
    exchangeable?
  end

  def holdable?
    true
  end

  def editable?
    (status == Order::EXCHANGING) || super
  end

  def holding_seats?
    HOLDING_SEAT_STATUSES.include?(status)
  end

  def sold?
    exchangeable?
  end

  def processed_or_fulfilled?
    processed? || fulfilled?
  end

  def seating_check_required?
    # NEW orders can be saved without seats selected yet
    # HOLD, PROCESSING, PROCESSED, and FULFILLED orders must have seats match tickets
    # Terminal statuses (REFUNDED, EXCHANGED, UNCLAIMED, CANCELED, SPLIT) should not validate
    validated_statuses = [Order::HOLD, Order::PROCESSING, Order::PROCESSED, Order::FULFILLED]
    validated_statuses.include?(status)
  end

  def assigned_seats?
    result = false
    ticket_line_items.each { |tli| result ||= tli.ticket_class.assigns_seats? }
    result
  end

  def wheelchair_requested?
    case
    when [WHEELCHAIR, WHEELCHAIR_TRANSFER].include?(special_request) then true
    when performance.production.has_reserved_seating? && !seats.select { |sa|
      !sa.accessibility.blank?
    }.empty? then true
    else false
    end
  end

  def seat_assignments(assignment_types = [])
    if performance.nil?
      r = ""
    else
      if performance.production.has_reserved_seating?
        show_seats = assignment_types.size.eql?(0) ? seats : seats.select { |s|
          assignment_types.include?(s.status)
        }
        r = show_seats.map { |s| s.seat.location }.sort.join(', ')
      elsif assigned_seats?
        r = ticket_detail_description.to_s
      else
        r = ""
      end
    end
    r
  end

  # when an order is saved to any status besides "EXCHANGING", any temporary seat assignments
  # are also associated with the newly generated order_id
  def finalize_seat_assignments
    if (processed? or held?) and performance.production.has_reserved_seating? and !uuid.nil?
      SeatAssignment.assign_seats_to_saved_order(uuid) unless exchanging?
    end
  end

  # For reserved-seating orders, ensure each SeatAssignment with a donation
  # price override is represented by a dedicated TicketLineItem carrying that
  # override (seat_assignment_id set, ticket_count=1). When the form was built
  # in the legacy aggregated-by-class shape, split an aggregated TLI off the
  # class so totals continue to balance.
  def sync_reserved_seat_price_overrides
    return unless performance&.production&.has_reserved_seating?
    return if exchanging?
    return unless [NEW, PROCESSING, PROCESSED, HOLD].include?(status)

    priced_seats = seats.where.not(price_override: nil).where.not(ticket_class_id: nil)
    return if priced_seats.empty?

    priced_seats.each do |sa|
      next if ticket_line_items.any? { |tli| tli.seat_assignment_id == sa.id }

      aggregated = ticket_line_items.detect { |tli|
        tli.ticket_class_id == sa.ticket_class_id && tli.seat_assignment_id.nil? && tli.ticket_count.to_i.positive?
      }
      next if aggregated.nil?

      if aggregated.ticket_count > 1
        aggregated.update_columns(ticket_count: aggregated.ticket_count - 1)
        ticket_line_items.create!(
          ticket_class_id: sa.ticket_class_id,
          ticket_count: 1,
          seat_assignment_id: sa.id,
          price_override: sa.price_override
        )
      else
        aggregated.update_columns(seat_assignment_id: sa.id, price_override: sa.price_override)
      end
    end
  end

  def display_code
    performance.try(:performance_code)
  end

  def description
    performance_s = performance.nil_or.to_short_s
    "#{performance_s} (#{ticket_detail_description})"
  end

  def to_s
    ticket_detail_description
  end

  def reload_associated
    super
    preset_line_items
  end

  def preset_line_items
    super
    unless finalized?
      tcs = ticket_line_items.map { |li| li.ticket_class_id }.uniq
      available = performance.ticket_class_allocations.select { |tca|
        tca.available? && !tcs.include?(tca.ticket_class.id) && tca.ticket_class.web_visible?
      }.map { |tca| tca.ticket_class }
      available.each { |tc| ticket_line_items.build(:ticket_class => tc, :ticket_count => 0) }
      ticket_line_items.order(:ticket_class_id)
    end
  end

  def valid_payment_types_for(current_user)
    valid_payment_types = super
    valid_payment_types = valid_payment_types - performance.restricted_payment_types unless performance.nil?
    valid_payment_types
  end

  def ticket_detail_description
    ticket_line_items.select { |tli| !tli.ticket_count.nil? && tli.ticket_count > 0 }.map { |li|
      if (li.ticket_count.nil? ? 0 : li.ticket_count) > 0
        li.to_s
      else
        ""
      end
    }.join(', ')
  end

  # @todo remove when multiple performances for an order are allowed
  def performances
    [performance]
  end

  def associated_theater_id
    if performance.nil?
      super
    else
      performance.production.theater_id
    end
  end

  ##
  # Check if there is any ticket line item whose ticket class is not complementary

  def all_tickets_complimentary?
    ticket_line_items.joins(:ticket_class).where.not(ticket_classes: { complimentary: false }).exists?
  end

  def send_to_printer(batch_id, batch_sequence = nil)
    # DEPRECATED: Use send_to_printer_api instead
    # This method is deprecated and kept only for backward compatibility
    Rails.logger.warn("DEPRECATED: send_to_printer is deprecated, use send_to_printer_api instead")
    send_to_printer_api(batch_id, batch_sequence)
  end

  # New API-based method for sending orders directly to tktprint service
  # If print_order_id exists, it will reprint the existing order
  # Otherwise, it will create a new order in tktprint
  def send_to_printer_api(batch_id, batch_sequence = nil)
    require 'cgi'
    raise ArgumentError, "batch_id is required" if batch_id.blank?

    batch_sequence ||= 1

    return unless $TKTPRINT['service'].present?

    # If we already have a print_order_id, reprint the existing order
    if print_order_id.present?
      return reprint_existing_order(batch_id, batch_sequence)
    end

    # Otherwise, create a new order in tktprint
    order_payload = build_tktprint_payload(batch_id, batch_sequence)

    # Send to tktprint API and return the tktprint order ID
    send_order_to_tktprint_api(order_payload)
  end

  private

  def build_tktprint_payload(batch_id, batch_sequence)
    # Build customer name
    cleaned_name, f_name, l_name = Address.parse_name(hold_under.blank? ? address.full_name : hold_under)
    if cleaned_name == address.full_name
      use_last_name = address.last_name
      use_first_name = address.first_name
    else
      use_last_name = l_name
      use_first_name = f_name
    end

    # Build credits
    credit_1 = nil
    credit_2 = nil
    unless performance.production.credit_lines.blank?
      credit_lines = performance.production.credit_lines.split("\n")
      credit_1 = credit_lines[0] unless credit_lines.nil?
      credit_2 = credit_lines[1] unless credit_lines.size < 2
    end

    # Calculate visible amount (excluding line items with hide_pricing=true)
    visible_amount = 0
    unique_line_items.select { |li| !li.special_offer_id.nil? || li.ticket_count > 0 }.each do |oli|
      if oli.is_a?(TicketLineItem) && oli.ticket_class&.hide_pricing
        next
      else
        visible_amount += oli.receipt_total
      end
    end

    # Build main order payload
    order_payload = {
      last_name: use_last_name,
      first_name: use_first_name,
      performance_code: performance_code,
      venue: CGI.unescapeHTML(performance.production.venue.name.to_s),
      theater: CGI.unescapeHTML(theater.name.to_s),
      title: CGI.unescapeHTML(performance.production.name.to_s),
      credit_1: credit_1 ? CGI.unescapeHTML(credit_1) : nil,
      credit_2: credit_2 ? CGI.unescapeHTML(credit_2) : nil,
      patron_code: address.customer_tag,
      performance_date: performance.performance_date,
      performance_time: performance.performance_time,
      amount: visible_amount,
      remote_id: id,
      batch_id: batch_id,
      batch_sequence: batch_sequence,
      line_items_attributes: [],
      payments_attributes: [],
      tickets_attributes: []
    }

    # Add line items
    unique_line_items.select { |li| !li.special_offer_id.nil? || li.ticket_count > 0 }.each do |oli|
      line_item_amount = oli.receipt_total
      if oli.is_a?(TicketLineItem) && oli.ticket_class&.hide_pricing
        line_item_amount = 0
      end

      order_payload[:line_items_attributes] << {
        description: oli.receipt_description,
        amount: line_item_amount
      }
    end

    # Add payments
    payments.each do |pay|
      unless pay.receipt_description.blank?
        order_payload[:payments_attributes] << {
          description: pay.receipt_description,
          amount: pay.customer_visible_amount
        }
      end
    end

    # Add tickets with current seat assignments
    tli_index = 0
    ticket_line_items.each do |tli|
      tli.ticket_count.times do
        seat_location = ""
        if performance.production.has_reserved_seating? && !seats[tli_index].nil?
          seat_location = seats[tli_index].seat.location
        end

        order_payload[:tickets_attributes] << {
          ticket_class: tli.ticket_class.class_code,
          seat: seat_location
        }
        tli_index += 1
      end
    end

    order_payload
  end

  def reprint_existing_order(batch_id, batch_sequence)
    require 'net/http'
    require 'uri'
    require 'json'

    tktprint_url = $TKTPRINT['service']
    base_uri = URI(tktprint_url)

    # Build the HTTP connection
    http = Net::HTTP.new(base_uri.host, base_uri.port)
    http.use_ssl = base_uri.scheme == 'https'

    # Send full updated order payload with the reprint request
    payload = build_tktprint_payload(batch_id, batch_sequence)

    # Create PUT request to reprint endpoint
    request = Net::HTTP::Put.new("/orders/#{print_order_id}/reprint.json")
    request.body = payload.to_json
    request['Content-Type'] = 'application/json'
    request['Accept'] = 'application/json'

    # Add basic auth if configured
    if base_uri.user && base_uri.password
      request.basic_auth(base_uri.user, base_uri.password)
      Rails.logger.debug("TktPrint: Adding Basic Auth for user: #{base_uri.user}")
    else
      Rails.logger.warn("TktPrint: No credentials found in service URL")
    end

    Rails.logger.info("TktPrint: Reprinting existing order #{id} (tktprint ID: #{print_order_id})")

    response = http.request(request)

    if response.code.to_i.between?(200, 299)
      Rails.logger.info("Successfully marked order #{id} for reprint in tktprint")
      print_order_id # Return the existing print_order_id
    else
      error_msg = "Failed to reprint order #{id} in tktprint: #{response.code} #{response.body}"
      Rails.logger.error(error_msg)
      raise error_msg
    end
  rescue => e
    Rails.logger.error("Error reprinting order #{id} in tktprint API: #{e.message}")
    raise e
  end

  def send_order_to_tktprint_api(payload)
    require 'net/http'
    require 'uri'
    require 'json'
    require 'cgi'

    tktprint_url = $TKTPRINT['service']

    # Parse the base URL to extract credentials and host
    base_uri = URI(tktprint_url)

    # Build the HTTP connection (without credentials in URL)
    http = Net::HTTP.new(base_uri.host, base_uri.port)
    http.use_ssl = base_uri.scheme == 'https'

    # Create the request with just the path (no host/credentials)
    request = Net::HTTP::Post.new('/orders.json')
    request.body = payload.to_json
    request['Content-Type'] = 'application/json'
    request['Accept'] = 'application/json'

    # Add basic auth if configured (this will add the Authorization header)
    if base_uri.user && base_uri.password
      request.basic_auth(base_uri.user, base_uri.password)
      Rails.logger.debug("TktPrint: Adding Basic Auth for user: #{base_uri.user}")
    else
      Rails.logger.warn("TktPrint: No credentials found in service URL")
    end

    # Log the request for debugging
    Rails.logger.debug("TktPrint: Sending POST to #{base_uri.host}:#{base_uri.port}/orders.json")
    Rails.logger.debug("TktPrint: Authorization header present: #{!request['Authorization'].nil?}")

    response = http.request(request)

    if response.code.to_i.between?(200, 299)
      Rails.logger.info("Successfully sent order #{id} to tktprint API")

      # Parse response to extract tktprint order ID
      begin
        response_data = JSON.parse(response.body)
        tktprint_order_id = response_data['id']
        Rails.logger.info("Tktprint order ID: #{tktprint_order_id}")
        tktprint_order_id
      rescue JSON::ParserError => e
        Rails.logger.warn("Failed to parse tktprint response: #{e.message}")
        nil
      end
    else
      error_msg = "Failed to send order #{id} to tktprint: #{response.code} #{response.body}"
      Rails.logger.error(error_msg)
      raise error_msg
    end
  rescue => e
    Rails.logger.error("Error sending order #{id} to tktprint API: #{e.message}")
    raise e
  end

  public

  def number_of_tickets
    if ticket_line_items.empty?
      result = 0
    else
      result = ticket_line_items.inject(0) { |sum, li| sum + (li.ticket_count.nil? ? 0 : li.ticket_count) }
    end
    result || 0
  end

  def number_of_seats
    if ticket_line_items.empty?
      0
    else
      ticket_line_items.select { |tli|
        !tli.nil? && !tli.ticket_class.nil? && tli.ticket_class.holds_seats?
      }.inject(0) { |sum, li| sum + (li.ticket_count.nil? ? 0 : li.ticket_count) }
    end
  end

  #
  # Returns a hashmap of each individual ticket with a reference to it's source ticket_line_item
  # and an associated seat.  Used for splitting seats
  #

  def flatten_ticket_line_items
    tickets = []
    adjust_seating_to_match_ticket_line_items
    seat_assignments = seats.map { |sa| sa }
    ticket_line_items.each do |tli|
      tli.ticket_count.times {
        seat = nil
        if tli.seat_assignment_id.present?
          # Per-seat TLI: the association is authoritative. Pull the seat directly
          # out of the pool so later iterations don't double-assign it.
          seat = seat_assignments.find { |sa| sa.id == tli.seat_assignment_id }
          seat_assignments.delete_at(seat_assignments.index(seat)) if seat
        elsif seat_assignments.map { |sa| sa.ticket_class_id }.include?(tli.ticket_class_id)
          # LEGACY: pre-per-seat-TLI reserved orders (seat_assignment_id is NULL).
          # Pool-match by ticket_class_id. Do not remove without auditing
          # historical TicketOrders.
          seat = seat_assignments.select { |sa| sa.ticket_class_id == tli.ticket_class_id }.first
          seat_assignments.delete_at(seat_assignments.index(seat))
        else
          # Log when we have tickets without matching seat assignments
          Rails.logger.warn("Order #{id}: Ticket without matching seat assignment for ticket_class_id #{tli.ticket_class_id}")
        end
        item = { source: tli, seat: seat, ticket_class_id: tli.ticket_class_id }
        tickets << item
      }
    end
    tickets
  end

  def self.create_ticket_line_item_for_split(original_ticket_line_item, ticket_class_id, seat_assignment = nil)
    unless seat_assignment.nil?
      seat_assignment.ticket_class_id = ticket_class_id
      seat_assignment.save!
    end
    { source: original_ticket_line_item, seat: seat_assignment, ticket_class_id: ticket_class_id }
  end

  def flatten_payments
    fpayments = Hash.new
    payments.each do |payment|
      if fpayments.key?(payment.payment_type_id)
        fpayments[payment.payment_type_id].amount += payment.amount
      else
        fpayments[payment.payment_type_id] = payment.dup
      end
    end
    fpayments
  end

  # utility routine for ticket splits
  def move_ticket_to_split(tli_hash, split_order, value_per_ticket, original_payments, split_payments)
    source_tli = tli_hash[:source]
    seat = tli_hash[:seat]
    dup_tli = source_tli.dup
    dup_tli.order_id = nil
    dup_tli.ticket_count = 1
    # The moved TLI takes ownership of its split seat (if any). The reversing
    # offset must leave seat_assignment_id NULL so the 1:1 unique index is
    # never violated by the accounting entry left behind on the source order.
    dup_tli.seat_assignment_id = seat&.id
    offset = dup_tli.dup
    offset.ticket_count = -1
    offset.seat_assignment_id = nil
    dup_tli.price_override = value_per_ticket
    dup_tli.generated_from_split = true
    total = dup_tli.price_override

    loop do
      source_payment_key = original_payments.keys[0]
      source_payment = original_payments.values[0]
      unless source_payment.nil?
        credit = [source_payment.amount, total].min
        offset_payment = source_payment.new_offset_payment(credit, 1)
        payments << offset_payment
        if split_payments.key?(source_payment_key)
          split_payments[source_payment_key].amount += offset_payment.new_offset_payment.amount
          split_payments[source_payment_key].number_of_tickets += offset_payment.new_offset_payment.number_of_tickets unless split_payments[source_payment_key].number_of_tickets.nil?
        else
          split_payments[source_payment_key] = offset_payment.new_offset_payment
          # split_payments[source_payment_key] = offset_payment.new_offset_payment

        end
        original_payments.delete(source_payment_key) if (!source_payment.nil? || source_payment.amount == 0) && (original_payments.size > 1)
        total -= credit
      end
      break if total.eql?(0.0)
    end
    dup_tli.order = split_order
    split_order.ticket_line_items << dup_tli
    unless tli_hash[:seat].nil?
      tli_hash[:seat].order_uuid = split_order.uuid
      tli_hash[:seat].save!
      split_order.seats << tli_hash[:seat]
    end
    ticket_line_items << offset
  end

  # split a ticket order into two like orders.  The current order has all its tickets removed
  #
  # params:
  # new_tlis -- an array of hashes from the original order with ticket_line_item and seat (see flatten_ticket_items)
  def split(new_tlis, all_tlis = nil)
    result = [nil, nil]
    TicketOrder.transaction do
      total_transfer_amount = CurrencyUtils.float_to_currency_decimal(total_paid - service_line_items.sum(:amount))
      split_value_per_ticket = CurrencyUtils.float_to_currency_decimal((total_transfer_amount / number_of_tickets).floor(2))
      original_payment_hash = flatten_payments

      order1 = fork_order_into_split
      order2 = fork_order_into_split
      order1_payments = Hash.new
      order2_payments = Hash.new
      remaining_tickets = all_tlis || flatten_ticket_line_items
      # Per-seat TLIs hold a unique seat_assignment_id FK. The source order is
      # losing all its seats (each seat's order_uuid is reassigned to a split
      # order below), so release every FK now — before any dup TLI is saved
      # to a split order — so the 1:1 unique index doesn't reject the dup.
      # The seat→TLI pairings are already captured in remaining_tickets, so
      # clearing the persisted FKs in bulk is safe. The form pairs split rows
      # by index, which may not match each TLI's original FK, so we cannot
      # rely on a per-iteration "release only when seat matches" check.
      ticket_line_items.where.not(seat_assignment_id: nil).update_all(seat_assignment_id: nil)
      # Also clear any orphan line_items (order_id IS NULL) that hold one of
      # the seat_assignment_ids being moved to a split order. These rows are
      # dead — they belong to no order — but the unique index still treats
      # them as live and would reject our dup TLIs. Scoping to seats that are
      # actually being split keeps this surgical.
      seat_ids_to_release = remaining_tickets.map { |t| t[:seat]&.id }.compact
      if seat_ids_to_release.any?
        LineItem.where(order_id: nil, seat_assignment_id: seat_ids_to_release).delete_all
      end
      0
      new_tlis.each do |tli_hash|
        find_index = remaining_tickets.find_index(tli_hash)
        throw "Can't split order because request for seats improperly generated" if find_index.nil?
        move_ticket_to_split(tli_hash, order1, split_value_per_ticket, original_payment_hash, order1_payments)
        remaining_tickets.delete_at(find_index)
      end
      remaining_tickets.each do |tli_hash|
        move_ticket_to_split(tli_hash, order2, split_value_per_ticket, original_payment_hash, order2_payments)
      end
      self.status = SPLIT
      cancel_pending_tasks
      save!
      order1_payments.each_value { |p| order1.payments << p }
      order2_payments.each_value { |p| order2.payments << p }
      order1.print_order_id = nil
      order2.print_order_id = nil
      order1.save!
      order2.save!
      result = [order1, order2]
    rescue ActiveRecord::RecordInvalid => e
      errors.add(:base, "Could not split order: #{e.message}")
      Rails.logger.debug(e)
    end
    result
  end

  # Returns orders that this was split to
  #
  def split_to_orders
    if split?
      TicketOrder.where(split_source_id: id).all
    else
      TicketOrder.where(split_source_id: -1).all
    end
  end

  def performance_code=(string)
    self.performance = Performance.find_by_performance_code(string)
  end

  def number_of_tickets_of_all_payments
    number_of_tickets = payments.to_a.sum { |fpp| fpp.number_of_tickets.nil? ? 0 : fpp.number_of_tickets }
    number_of_tickets = 0 if number_of_tickets.nil?
    number_of_tickets
  end

  def attended?
    [PROCESSED, FULFILLED].include?(status)
  end

  def ticket_quantity_by_class(class_code)
    ticket_line_items.to_a.sum { |li| li.ticket_class.class_code == class_code ? li.ticket_count : 0 }
  end

  def ticket_quantity
    ticket_line_items.sum(:ticket_count)
  end

  def complimentary_ticket_count
    ticket_line_items.select(&:complimentary?).sum(&:ticket_count)
  end

  def royalty_gross
    return BigDecimal('0') if total_paid <= 0

    ticket_total = ticket_line_items.to_a.sum(&:royalty_total)
    if !split? && special_offer_line_item&.special_offer
      ticket_total += special_offer_line_item.special_offer.calculate_royalty_discount(self)
    end
    ticket_total = BigDecimal('0') if ticket_total < 0
    CurrencyUtils.float_to_currency_decimal(ticket_total)
  end

  def ticketing_fee
    super + CurrencyUtils.float_to_currency_decimal(ticket_line_items.to_a.sum { |li|
      li.ticket_class.ticketing_fee * li.ticket_count
    })
  end

  def contains_tickets?
    !ticket_line_items.select { |li| li.ticket_count > 0 }.empty?
  end

  def exchanged_for
    o = Order.where(exchange_source_id: id)
    if o.empty?
      nil
    else
      o.first
    end
  end

  def create_offset_payments
    sorted = payments.sort { |a, b| b.amount <=> a.amount }
    service_fee = service_line_items.sum(:amount)
    Array.new
    offsets = sorted.map do |p|
      offset = p.new_exchange_offset_payment
      if service_fee > 0 then
        diff = [-service_fee, offset.amount].max
        offset.amount -= diff
        service_fee += diff
      end
      offset
    end
    offsets.select { |p| p.amount != 0 }
  end

  def total_ticket_face_value(reload_line_items = false)
    a = ticket_line_items.to_a.sum { |line_item| line_item.respond_to?(:total) ? line_item.total : 0 }
    a = 0.0 if a < 0.0
    a
  end

  def begin_exchange!(original_order)
    Order.transaction do
      self.exchange_source = original_order
      self.address = original_order.address
      self.status = Order::EXCHANGING
      exchange_source.status = Order::RELEASING

      exchange_payments_on_original_order = original_order.create_offset_payments
      exchange_payments_toward_exchange_order = payment_type.build_exchange_offset_payments(exchange_payments_on_original_order)
      exchange_payments_on_original_order.each { |p| original_order.payments << p unless p.nil? }
      exchange_payments_toward_exchange_order.each { |p| payments << p unless p.nil? }
      payment_difference = total_due - exchange_payments_toward_exchange_order.inject(0) { |sum, x|
        sum + x.amount
      }
      if payment_difference < 0
        payments << PriceOverridePayment.new(:amount => payment_difference, :order => self,
                                                  :source_payment_type => original_order.payment_type)
      elsif payment_difference > 0
        create_proper_payment_in_amount_of!(payment_difference)
      end

      update_special_offer_line_item_from_code!
      save!
    end
  end

  def transition_processing_to_exchanging!
    transition_processing_to_processing!
  end

  def transition_exchanging_to_processed!
    Order.transaction do
      original_order = exchange_source
      self.status = Order::PROCESSED
      set_email_confirmation
      payments.reload
      save!
      original_order.status = Order::EXCHANGED
      original_order.release_tickets!
      original_order.save!
    end
  end

  def exchange_and_process_from!(original_order)
    Order.transaction do
      begin_exchange!(original_order)
      transition_exchanging_to_processed!
    end
  end

  def convert_to_donation!
    raise "Order is not convertible to a donation" unless convertible_to_donation?

    Order.transaction do
      donation_amount = total_paid

      donation = DonationOrder.new(
        address: address,
        payment_type: payment_type,
        theater: theater,
        campaign: performance&.production&.name,
        status: Order::PROCESSED
      )
      donation.donation_line_items.build(amount: donation_amount)
      donation.save!

      payments.each { |payment| payment.update!(order_id: donation.id) }

      unassign_seats
      ticket_line_items.each { |tli| tli.destroy! }

      self.status = Order::CANCELED
      self.notes = [notes, "Converted to Donation Order ##{donation.id}"].compact.join("\n")
      save!

      donation
    end
  end

  def release_tickets!
    ticket_line_items.each { |ti| ti.destroy }
    unassign_seats
    payments.each { |p| p.release_tickets! }
  end

  def reservation_date
    performance.performance_date
  end

  def all_line_items(reload_line_items = false)
    ticket_line_items.reload if reload_line_items
    super(reload_line_items) + ticket_line_items
  end

  # for form processing
  def production_code=(string)
    @production_code = string
  end

  def production_code()
    performance.try(:production).try(:production_code) || @production_code
  end

  def performance_code=(string)
    self.performance = Performance.find_by_performance_code(string)
  end

  def performance_code()
    performance.try(:performance_code)
  end

  def unique_line_items(reload_line_items = false)
    (super +
        ticket_line_items
    ).uniq
  end

  def production_ticket_class_from_offer(offer)
    performance.production.ticket_classes.select { |tc| tc.class_code == offer.use_ticket_class_code }.first
  end

  def create_default_service_fees(for_production = nil)
    if !for_production.nil?
      for_production.service_item_templates_new.each do |template|
        service_line_items.build(template.attributes_for_service_item)
      end
    elsif !performance.nil?
      performance.production.service_item_templates_new.each do |template|
        service_line_items.build(template.attributes_for_service_item)
      end
    end
    service_line_items
  end

  def create_exchange_service_fees(original_order)
    templates = Array.new

    if original_order.exchange_source.nil?
      templates = original_order.performance.production.service_item_templates_first_exchange
    else
      templates = original_order.performance.production.service_item_templates_addl_exchange
    end
    templates.each do |template|
      service_line_items.build(template.attributes_for_service_item)
    end
    service_line_items
  end

  # Alter altering tickets, seating tags must be adjusted if necessary
  #
  # @new_tlis -- Can be either an array of newly created ticket_line_items or s single ticket_line_item
  # @old_tlis -- Can be either an array of previous  ticket_line_items or s single ticket_line_item
  #
  # Notes:
  #   If either new_tlis or old_tlis are nil, then the seating is forced to match the existing ticket line items ticket assignments blindly.
  def adjust_seating_to_match_ticket_line_items(new_tlis = nil, old_tlis = nil)
    if performance.production.has_reserved_seating?
      # Reserved-seating orders now maintain 1 TicketLineItem per SeatAssignment
      # via TicketLineItem#seat_assignment_id. When that invariant holds there is
      # nothing to reconcile — the association itself guarantees the pairing.
      if ticket_line_items.any? && ticket_line_items.all? { |tli| tli.seat_assignment_id.present? }
        return
      end

      # LEGACY: pre-per-seat-TLI reserved orders (TicketLineItem#seat_assignment_id is NULL).
      # Do not remove without auditing historical TicketOrders.
      Hash.new
      if new_tlis.nil?
        tli_ticket_class_ids = Set.new(ticket_line_items.map { |tli| tli.ticket_class_id })
      else
        new_tlis = [new_tlis] unless new_tlis.kind_of?(Array)
        tli_ticket_class_ids = Set.new(new_tlis.map { |tli| tli.ticket_class_id })
      end
      seat_ticket_class_ids = Set.new(seats.map { |s| s.ticket_class_id })

      if old_tlis.nil?
        tc_ids_for_reassign = seat_ticket_class_ids - tli_ticket_class_ids
        ticket_line_items.select { |tli| tc_ids_for_reassign.include?(tli.ticket_class_id) }
      else
        old_tlis = [old_tlis] unless old_tlis.kind_of?(Array)
        tc_ids_for_reassign = Set.new(old_tlis.map { |tli| tli.ticket_class_id })
      end
      tc_ids_to_fix = tli_ticket_class_ids - seat_ticket_class_ids # ticket_class_ids that don't exist in seat
      new_tlis = ticket_line_items.select { |tli| tc_ids_to_fix.include?(tli.ticket_class_id) } if new_tlis.nil?

      tc_id_pool = []
      new_tlis.each do |tli|
        tli.ticket_count.times do
          tc_id_pool.push(tli.ticket_class_id)
        end
      end

      seats.select { |sa| tc_ids_for_reassign.include?(sa.ticket_class_id) }.each do |seat_assignment|
        seat_assignment.ticket_class_id = tc_id_pool.pop
      end
    end
  end

  protected

  def fork_order_into_split
    result = dup
    result.uuid = SecureRandom.uuid
    result.do_not_create_tasks = true
    result.split_source_id = id
    tasks.each { |task| result.tasks << task.dup }
    result
  end

  def refund_line_items(reversing_entries)
    reversing_entries.each { |e| ticket_line_items << e }
    super(reversing_entries)
  end

  def transition_new_to_fulfilled!(redirect_to = nil)
    redirect_to = transition_new_to_processed!(redirect_to)
    transition_processed_to_fulfilled!(redirect_to)
  end

  def transition_processing_to_processing!(redirect_to = nil)
    transition_new_to_processing!(redirect_to)
  end

  def transition_processing_to_hold!(redirect_to = nil)
    transition_new_to_hold!(redirect_to)
  end

  def transition_new_to_hold!(redirect_to = nil)
    self.status = Order::HOLD
    save!
    redirect_to
  end

  def transition_processed_to_fulfilled!(redirect_to = nil)
    # Queue the print job - status will be changed to FULFILLED by the job on success
    batch_id = PrintingService.print_order(id, batch_type: :individual)
    Rails.logger.info("Order #{id} queued for printing in batch #{batch_id}")

    # NOTE: We do NOT call super here because the PrintBatchJob will mark the order
    # as FULFILLED after successful printing. This prevents orders from being marked
    # as fulfilled when printing fails.
    redirect_to
  end

  def transition_fulfilled_to_fulfilled!(redirect_to = nil)
    transition_processed_to_fulfilled!(redirect_to)
  end

  def transition_fulfilled_to_unclaimed!(redirect_to = nil)
    transition_processed_to_unclaimed!(nil)
  end

  def transition_processed_to_unclaimed!(redirect_to = nil)
    unclaimed!
  end

  def self.applicable_price(regular_ticket_class, offer_ticket_class)
    [regular_ticket_class.ticket_price, offer_ticket_class.ticket_price].min
  end

  def set_defaults
    ticket_line_items.each { |tli| tli.order = self if tli.order.nil? }
  end

  def set_tasks_on_save
    if do_not_create_tasks.nil? && (new_record? || saved_change_to_status?)
      super
      case status
      when PROCESSED
        create_reminder_task
      when FULFILLED
        create_performance_followup_task
      end
    end
  end

  def create_reminder_task
    if do_not_create_tasks.nil? || (contains_tickets? && !performance.suppress_notification)
      day_before = performance.performance_date.to_datetime - 1.day
      tasks << OutreachTask.new(:execute_at => day_before,
                                     :method_symbol => :performance_reminder) unless day_before - 1.day < Time.now
    end
  end

  def create_receipt_task
    tasks << OutreachTask.new(:execute_at => Time.now + 5.minutes,
                                   :method_symbol => :ticket_confirmation) unless performance.suppress_notification || suppress_receipt? || !do_not_create_tasks.nil? || performance.performance_date < Date.today
    if !$EMAIL_ADDRESS.nil? && !$EMAIL_ADDRESS['wheelchair_conversion_notifications'].blank? && wheelchair_requested?
      tasks << NotificationTask.new(:execute_at => Time.now + 15.minutes,
                                         :notifications => $EMAIL_ADDRESS['wheelchair_conversion_notifications'],
                                         :method_symbol => :wheelchair_conversion_alert)
    end
    super
  end

  def create_notify_refund_task
    tasks << NotificationTask.new(:execute_at => Time.now, :notifications => [$EMAIL_ADDRESS['box_office'], $EMAIL_ADDRESS['supervisor_notifications']].join(','),
                                       :method_symbol => :refunded_fulfilled_item_alert) unless $EMAIL_ADDRESS.nil? || !do_not_create_tasks.nil?
    super
  end

  def create_performance_followup_task
    if do_not_create_tasks.nil?
      if contains_tickets? && !performance.suppress_notification && performance.production.use_ticket_email_templates?
        monday_following = performance.performance_date.end_of_week + 1.day
        case
        when address.current_member?
          tasks << OutreachTask.new(:execute_at => monday_following, :method_symbol => :member_followup)
        when paid_with_flexpass?
          tasks << OutreachTask.new(:execute_at => monday_following, :method_symbol => :flex_pass_followup)
        when address.first_time_paying?(self)
          tasks << OutreachTask.new(:execute_at => monday_following, :method_symbol => :first_time_followup)
        else
          tasks << OutreachTask.new(:execute_at => monday_following, :method_symbol => :standard_followup)
        end
      end
    end
  end

  def suppress_receipt?
    performance.suppress_notification || ticket_line_items.map { |tli|
      tli.ticket_class.suppress_receipt?
    }.all?
  end

  def remove_empty_ticket_lines
    ticket_line_items.map { |li| li.ticket_class.id }.uniq
    ticket_line_items.each do |li|
      ticket_line_items.delete(TicketLineItem.find(li.id)) if li.ticket_count == 0 && !li.id.nil?
    end
  end

  private

  def set_ticket_classes_using_offer(offer)
    new_ticket_class = production_ticket_class_from_offer(offer)
    if !new_ticket_class.nil?
      ticket_line_items.each { |li|
        new_line_item = TicketLineItem.new
        new_line_item.ticket_class = new_ticket_class
        li.ticket_class.ticket_price
        new_line_item.ticket_count = li.ticket_count
        new_line_item.price_override = TicketOrder.applicable_price(li.ticket_class,
                                                                    new_ticket_class) if new_ticket_class.ticket_type == TicketClass::DONATION
        ticket_line_items << new_line_item
        ticket_line_items.delete(li)
        adjust_seating_to_match_ticket_line_items(new_line_item, li)
      }
    end
  end

  def update_attendance_record
    if saved_change_to_status?
      begin
        case status
        when Order::FULFILLED
          # In a Rails console or in your Rails application code
          ActiveRecord::Base.connection.execute("SELECT COUNT(*) FROM addresses_productions").first[0]
          performance.production
          production.addresses << address
          # In a Rails console or in your Rails application code

        when Order::REFUNDED, Order::UNCLAIMED
          address.productions.delete(production) if is_unique_visit?
        end
      rescue StandardError => e
        Rails.logger.error "Failed to update attendee status for order #{id}: #{e.message}"
        Rails.logger.error "Backtrace:\n#{e.backtrace.join("\n")}"
      end
    end
  end

  def reverse_source_exchange_payments
    exchange_source.payments.select { |p| p.can_cancel? }.each { |p|
      p.destroy!
    }
    exchange_source.status = Order::PROCESSED
    exchange_source.save!
  end

  def is_unique_visit?(prod = nil)
    prod = prod || production
    TicketOrder.joins(:performance).where("performances.production_id = ? and orders.id != ? and orders.status = ? and orders.address_id = ?",
                                          prod.id,
                                          id,
                                          Order::FULFILLED,
                                          address_id).count == 0
  end

  def set_tickets_for_pass_redemption
    if status_changed? && status == Order::PROCESSED
      if paid_with_flexpass?
        flex_pass = paid_with_flexpass
        offer = flex_pass.flex_pass_offer
        set_ticket_classes_using_offer(offer)
      end
      if paid_with_membership?
        membership = Membership.find_by_member_code(member_code)
        offer = membership.membership_offer
        set_ticket_classes_using_offer(offer)
        ticket_line_items
      end
    end
  end

  def debug_logger
    @@debug_logger ||= Logger.new("#{Rails.root}/log/debug.log")
  end

  def set_theater
    self.theater_id = associated_theater_id
  end
end
