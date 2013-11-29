class PrintTicketOrder
  @queue = :printing

  def self.perform(order_id)

    o = TicketOrder.find(order_id)
    o.send_to_printer
    o.save!
  end
end
