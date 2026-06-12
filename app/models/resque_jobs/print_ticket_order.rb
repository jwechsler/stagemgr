class PrintTicketOrder
  @queue = :printing

  def self.perform(order_id)
    # DEPRECATED: This job is deprecated in favor of PrintingService
    # Redirecting to the new unified batch-based printing system

    Rails.logger.warn('DEPRECATED: PrintTicketOrder.perform is deprecated. Redirecting to PrintingService.')

    # Use the new unified service instead of direct send_to_printer
    PrintingService.print_order(order_id, batch_type: :legacy)
  end
end
