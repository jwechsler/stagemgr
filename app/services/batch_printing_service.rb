class BatchPrintingService
  class << self
    def create_and_process_batch(orders)
      return false if orders.empty?
      
      order_ids = orders.map(&:id)
      
      Rails.logger.info("Creating bulk batch with orders: #{order_ids}")
      
      # Use unified PrintingService for batch printing
      PrintingService.print_orders(order_ids, batch_type: :bulk)
    end

    def process_orders_by_performance(performance_id, limit: 50)
      orders = TicketOrder.joins(:performance)
                          .where(performances: { id: performance_id })
                          .where(status: Order::PROCESSED)
                          .where.not(print_order_id: nil)
                          .limit(limit)
                          .order(:created_at)
      
      if orders.any?
        create_and_process_batch(orders)
      else
        Rails.logger.info("No orders found to print for performance #{performance_id}")
        nil
      end
    end

    def process_orders_by_theater(theater_id, limit: 50)
      orders = TicketOrder.joins(:theater)
                          .where(theaters: { id: theater_id })
                          .where(status: Order::PROCESSED)
                          .where.not(print_order_id: nil)
                          .limit(limit)
                          .order(:created_at)
      
      if orders.any?
        create_and_process_batch(orders)
      else
        Rails.logger.info("No orders found to print for theater #{theater_id}")
        nil
      end
    end

    def check_batch_status(batch_id)
      response = PrintBatchJob.send(:tktprint_request, :get, "print_batches/#{batch_id}")
      
      if response.success?
        JSON.parse(response.body)
      else
        { error: "Failed to get batch status: #{response.body}" }
      end
    rescue => e
      { error: "Error checking batch status: #{e.message}" }
    end

    private
  end
end