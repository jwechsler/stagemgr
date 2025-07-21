class PrintBatchJob
  @queue = :batch_printing

  def self.perform(batch_id, order_ids)
    Rails.logger.info("Starting print batch job: #{batch_id} with #{order_ids.length} orders")
    
    begin
      # Create the print batch in tktprint
      create_print_batch(batch_id)
      
      # Send each order to tktprint with batch information
      order_ids.each_with_index do |order_id, index|
        sequence = index + 1
        
        begin
          order = TicketOrder.find(order_id)
          Rails.logger.info("Processing order #{order_id} (sequence #{sequence}) for batch #{batch_id}")
          
          # Send to printer with batch information (batch_id and sequence are required)
          order.send_to_printer(batch_id, sequence)
          
          Rails.logger.info("Successfully sent order #{order_id} to printer")
        rescue => e
          Rails.logger.error("Error processing order #{order_id} in batch #{batch_id}: #{e.message}")
          # Continue with other orders even if one fails
        end
      end
      
      # Close the print batch to trigger printing
      close_print_batch(batch_id)
      
      Rails.logger.info("Completed print batch job: #{batch_id}")
      
    rescue => e
      Rails.logger.error("Error in print batch job #{batch_id}: #{e.message}")
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

    uri = URI("#{tktprint_url}/#{path}.json")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    
    case method
    when :post
      request = Net::HTTP::Post.new(uri)
      request.body = params.to_json
    when :put
      request = Net::HTTP::Put.new(uri)
      request.body = params.to_json
    when :get
      request = Net::HTTP::Get.new(uri)
    end
    
    request['Content-Type'] = 'application/json'
    request['Accept'] = 'application/json'
    
    # Add basic auth if configured
    if uri.user && uri.password
      request.basic_auth(uri.user, uri.password)
    end
    
    response = http.request(request)
    
    Rails.logger.debug("Tktprint API #{method.upcase} #{uri}: #{response.code} #{response.body}")
    
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