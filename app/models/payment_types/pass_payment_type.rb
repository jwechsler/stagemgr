class PassPaymentType < PaymentType
  # What a pass redemption charges for one ticket of line_item: the lesser of
  # the ticket's own price (its override, else its class price) and the pass
  # class price. The pass payment and the line items swapped into the pass
  # class (TicketOrder#set_ticket_classes_using_offer) both use it, so the
  # order balances.
  def self.applicable_price(line_item, pass_ticket_class)
    [line_item.price, pass_ticket_class.ticket_price].min
  end

  def build_exchange_offset_payments(_source_payments)
    []
  end
end
