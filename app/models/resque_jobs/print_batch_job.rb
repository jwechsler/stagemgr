class PrintBatchJob
  @queue = :batch_printing

  def self.perform(batch_id, order_ids)
    Rails.logger.info("Starting print batch job: #{batch_id} with #{order_ids.length} orders")

    successful_order_ids = []
    failed_order_ids = []

    begin
      # Create the print batch in tktprint
      create_print_batch(batch_id)

      # Send each order to tktprint with batch information
      order_ids.each_with_index do |order_id, index|
        sequence = index + 1

        begin
          order = TicketOrder.find(order_id)
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
          if order.status == Order::PROCESSED
            order.status = Order::FULFILLED
          end

          order.save!
          Rails.logger.info("Successfully sent order #{order_id} to printer (tktprint ID: #{tktprint_order_id})")

          successful_order_ids << order_id
        rescue => e
          Rails.logger.error("Error processing order #{order_id} in batch #{batch_id}: #{e.message}")
          Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
          failed_order_ids << order_id
          # Continue with other orders even if one fails
        end
      end

      # Close the print batch to trigger printing
      close_print_batch(batch_id)

      Rails.logger.info("Completed print batch job: #{batch_id} - #{successful_order_ids.length} successful, #{failed_order_ids.length} failed")

    rescue => e
      Rails.logger.error("Error in print batch job #{batch_id}: #{e.message}")
      Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
      raise e
    end
  end

  private

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

    tktprint_url = $TKTPRINT['service']
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
      Rails.logger.debug("TktPrint: Adding Basic Auth for user: #{base_uri.user}")
    else
      Rails.logger.warn("TktPrint: No credentials found in service URL")
    end
    
    response = http.request(request)

    Rails.logger.debug("Tktprint API #{method.upcase} #{base_uri.host}:#{base_uri.port}#{request_path}: #{response.code} #{response.body}")
    
    OpenStruct.new(
      success?: response.code.to_i.between?(200, 299),
      code: response.code.to_i,
      body: response.body
    )
  rescue => e
    Rails.logger.error("Error making tktprint request: #{e.message}")
    OpenStruct.new(success?: false, body: e.message)
  end
end