class PrintBatchJob
  @queue = :batch_printing

  def self.perform(batch_id, order_ids)
    Rails.logger.info("Starting print batch job: #{batch_id} with #{order_ids.length} orders")

    successful_order_ids = []
    failed_order_ids = []

    # Orders with nothing physical to print (e.g. streaming-only) are fulfilled
    # before tktprint is contacted, so they still complete when the printer
    # service is down or not configured at all (a streaming-only venue).
    printable_orders = fulfill_orders_without_printable_tickets(order_ids, successful_order_ids, failed_order_ids)
    if printable_orders.empty?
      Rails.logger.info("Completed print batch job: #{batch_id} - no printable orders; #{successful_order_ids.length} fulfilled without printing, #{failed_order_ids.length} failed")
      return
    end

    begin
      # Create the print batch in tktprint
      create_print_batch(batch_id)

      # Send each printable order to tktprint with batch information
      printable_orders.each_with_index do |(order_id, order), index|
        sequence = index + 1

        begin
          Rails.logger.info("Processing order #{order_id} (sequence #{sequence}) for batch #{batch_id}")

          # Send to printer API with batch information (batch_id and sequence are required)
          tktprint_order_id = order.send_to_printer_api(batch_id, sequence)

          # Update both print_order_id and status in a single save
          if tktprint_order_id.present?
            order.print_order_id = tktprint_order_id
          else
            Rails.logger.warn("Order #{order_id} sent to printer but no tktprint ID returned")
          end

          # Mark PROCESSED orders as FULFILLED after successful print
          order.status = Order::FULFILLED if order.status == Order::PROCESSED

          order.save!
          Rails.logger.info("Successfully sent order #{order_id} to printer (tktprint ID: #{tktprint_order_id})")

          successful_order_ids << order_id
        rescue StandardError => e
          Rails.logger.error("Error processing order #{order_id} in batch #{batch_id}: #{e.message}")
          Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
          failed_order_ids << order_id
          # Continue with other orders even if one fails
        end
      end

      # Close the print batch to trigger printing
      close_print_batch(batch_id)

      Rails.logger.info("Completed print batch job: #{batch_id} - #{successful_order_ids.length} successful, #{failed_order_ids.length} failed")
    rescue StandardError => e
      Rails.logger.error("Error in print batch job #{batch_id}: #{e.message}")
      Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
      raise e
    end
  end

  # Fulfills the orders that have no printable tickets and returns the rest
  # as [order_id, order] pairs, in their original order, for printing. An order that cannot be loaded or
  # saved is recorded as failed and left out of the batch.
  def self.fulfill_orders_without_printable_tickets(order_ids, successful_order_ids, failed_order_ids)
    order_ids.filter_map do |order_id|
      order = TicketOrder.find(order_id)
      next [order_id, order] if order.contains_printable_tickets?

      order.status = Order::FULFILLED if order.status == Order::PROCESSED
      order.save!
      Rails.logger.info("Order #{order_id} has no printable tickets; fulfilled without printing")
      successful_order_ids << order_id
      nil
    rescue StandardError => e
      Rails.logger.error("Error processing order #{order_id}: #{e.message}")
      failed_order_ids << order_id
      nil
    end
  end

  def self.create_print_batch(batch_id)
    Rails.logger.info("Creating print batch: #{batch_id}")

    response = tktprint_request(:post, 'print_batches', { batch_id: batch_id })

    if response.success?
      Rails.logger.info("Successfully created print batch: #{batch_id}")
    else
      error_msg = "Failed to create print batch #{batch_id}: #{response.body}"
      Rails.logger.error(error_msg)
      raise error_msg
    end
  end

  def self.close_print_batch(batch_id)
    Rails.logger.info("Closing print batch: #{batch_id}")

    response = tktprint_request(:put, "print_batches/#{batch_id}/close")

    if response.success?
      Rails.logger.info("Successfully closed print batch: #{batch_id}")
    else
      error_msg = "Failed to close print batch #{batch_id}: #{response.body}"
      Rails.logger.error(error_msg)
      raise error_msg
    end
  end

  def self.tktprint_request(method, path, params = {})
    require 'net/http'
    require 'uri'
    require 'json'

    tktprint_url = Rails.configuration.x.tktprint['service']
    return OpenStruct.new(success?: false, body: 'Tktprint service not configured') if tktprint_url.blank?

    # Parse base URI to extract credentials
    base_uri = URI(tktprint_url)
    request_path = "/#{path}.json"

    http = Net::HTTP.new(base_uri.host, base_uri.port)
    http.use_ssl = base_uri.scheme == 'https'

    # Create request with path only (not full URI)
    case method
    when :post
      request = Net::HTTP::Post.new(request_path)
      request.body = params.to_json
    when :put
      request = Net::HTTP::Put.new(request_path)
      request.body = params.to_json
    when :get
      request = Net::HTTP::Get.new(request_path)
    end

    request['Content-Type'] = 'application/json'
    request['Accept'] = 'application/json'

    # Add basic auth if configured
    if base_uri.user && base_uri.password
      request.basic_auth(base_uri.user, base_uri.password)
      Rails.logger.debug { "TktPrint: Adding Basic Auth for user: #{base_uri.user}" }
    else
      Rails.logger.warn('TktPrint: No credentials found in service URL')
    end

    response = http.request(request)

    Rails.logger.debug do
      "Tktprint API #{method.upcase} #{base_uri.host}:#{base_uri.port}#{request_path}: #{response.code} #{response.body}"
    end

    OpenStruct.new(
      success?: response.code.to_i.between?(200, 299),
      code: response.code.to_i,
      body: response.body
    )
  rescue StandardError => e
    Rails.logger.error("Error making tktprint request: #{e.message}")
    OpenStruct.new(success?: false, body: e.message)
  end
end
