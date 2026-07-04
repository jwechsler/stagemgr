class PrintingService
  class << self
    # Unified printing method that wraps all printing operations in batches
    # @param order_ids [Array<Integer>] Array of order IDs to print
    # @param batch_type [Symbol] Type of batch (:individual, :bulk, :reprint)
    # @return [String] batch_id of created batch
    def print_orders(order_ids, batch_type: :individual)
      order_ids = Array(order_ids) # Ensure it's an array
      batch_id = generate_batch_id(batch_type)

      Rails.logger.info("PrintingService: Creating #{batch_type} batch #{batch_id} for #{order_ids.length} orders")

      # Enqueue batch print job
      Resque.enqueue(PrintBatchJob, batch_id, order_ids)

      batch_id
    end

    # Print a single order (used for reprints and automatic printing)
    # @param order_id [Integer] ID of order to print
    # @param batch_type [Symbol] Type of batch (:individual, :reprint)
    # @return [String] batch_id of created batch
    def print_order(order_id, batch_type: :individual)
      print_orders([order_id], batch_type: batch_type)
    end

    # Reprint a single order
    # @param order_id [Integer] ID of order to reprint
    # @return [String] batch_id of created batch
    def reprint_order(order_id)
      print_order(order_id, batch_type: :reprint)
    end

    private

    # Generate unique batch ID with type prefix
    # @param batch_type [Symbol] Type of batch
    # @return [String] Generated batch ID
    def generate_batch_id(batch_type)
      timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
      random_suffix = SecureRandom.hex(4)
      prefix = batch_type.to_s.upcase

      "#{prefix}_#{timestamp}_#{random_suffix}"
    end
  end
end
