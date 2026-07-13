require 'net/http'
require 'uri'
require 'json'
require 'cgi'

# Sends a TicketOrder to the tktprint service: payload assembly plus the
# create (POST /orders.json) and reprint (PUT /orders/:id/reprint.json) API
# calls. Extracted verbatim from TicketOrder.
module TktprintPrintable
  extend ActiveSupport::Concern

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
    raise ArgumentError, "batch_id is required" if batch_id.blank?

    batch_sequence ||= 1

    return if Rails.configuration.x.tktprint['service'].blank?

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
    cleaned_name, f_name, l_name = Address.parse_name(hold_under.presence || address.full_name)
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
    if performance.production.credit_lines.present?
      credit_lines = performance.production.credit_lines.split("\n")
      credit_1 = credit_lines[0] unless credit_lines.nil?
      credit_2 = credit_lines[1] unless credit_lines.size < 2
    end

    # Calculate visible amount (excluding line items with hide_pricing=true)
    visible_amount = 0
    unique_line_items.select { |li| !li.special_offer_id.nil? || li.ticket_count > 0 }.each do |oli|
      next if oli.is_a?(TicketLineItem) && oli.ticket_class&.hide_pricing

      visible_amount += oli.receipt_total
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
      next if pay.receipt_description.blank?

      order_payload[:payments_attributes] << {
        description: pay.receipt_description,
        amount: pay.customer_visible_amount
      }
    end

    # Add tickets with current seat assignments. Per-seat TLIs resolve their
    # seat through seat_assignment_id; legacy aggregated TLIs (nil FK, class
    # holds seats) pool-match by ticket_class_id, mirroring
    # flatten_ticket_line_items. Non-seat tickets (holds_seats=false) print
    # with a blank seat, the same as general admission.
    seat_pool = performance.production.has_reserved_seating? ? seats.to_a : []
    ticket_line_items.each do |tli|
      tli.ticket_count.times do
        seat_location = ""
        if tli.ticket_class&.holds_seats?
          sa = if tli.seat_assignment_id.present?
                 seat_pool.find { |s| s.id == tli.seat_assignment_id }
               else
                 seat_pool.find { |s| s.ticket_class_id == tli.ticket_class_id }
               end
          if sa
            seat_pool.delete(sa)
            seat_location = sa.seat.location
          end
        end

        order_payload[:tickets_attributes] << {
          ticket_class: tli.ticket_class.class_code,
          seat: seat_location
        }
      end
    end

    order_payload
  end

  def reprint_existing_order(batch_id, batch_sequence)
    tktprint_url = Rails.configuration.x.tktprint['service']
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
      Rails.logger.debug { "TktPrint: Adding Basic Auth for user: #{base_uri.user}" }
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
  rescue StandardError => e
    Rails.logger.error("Error reprinting order #{id} in tktprint API: #{e.message}")
    raise e
  end

  def send_order_to_tktprint_api(payload)
    tktprint_url = Rails.configuration.x.tktprint['service']

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
      Rails.logger.debug { "TktPrint: Adding Basic Auth for user: #{base_uri.user}" }
    else
      Rails.logger.warn("TktPrint: No credentials found in service URL")
    end

    # Log the request for debugging
    Rails.logger.debug { "TktPrint: Sending POST to #{base_uri.host}:#{base_uri.port}/orders.json" }
    Rails.logger.debug { "TktPrint: Authorization header present: #{!request['Authorization'].nil?}" }

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
  rescue StandardError => e
    Rails.logger.error("Error sending order #{id} to tktprint API: #{e.message}")
    raise e
  end
end
