class PrintTicketOrder
  @queue = :printing

  def self.perform(order_id)
    # DEPRECATED: Use PrintBatchJob instead for new implementations
    # This method is kept for backward compatibility only
    
    Rails.logger.warn("DEPRECATED: PrintTicketOrder.perform is deprecated. Use PrintBatchJob instead.")
    
    o = TicketOrder.find(order_id)
    o.send_to_printer  # This will use individual printing without batch
    o.save!
  end
end
