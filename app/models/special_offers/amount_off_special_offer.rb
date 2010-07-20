class AmountOffSpecialOffer < SpecialOffer
  def calculate_discount(order)
    # the discount will either be negative the amount configured
    # or negative the sum total of all tickets of this class
    # which ever one is smaller
    [self.configuration_hash['amount_off'].to_f,order.line_items.for_ticket_class(self.ticket_class).map{|li|li.total}.sum].sort.first * -1
  end
  
end
