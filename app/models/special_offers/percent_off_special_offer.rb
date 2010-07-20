class PercentOffSpecialOffer < SpecialOffer
  def calculate_discount(order)
    order.line_items.for_ticket_class(self.ticket_class).map{|li|li.total}.sum * self.configuration_hash['percent_off'].to_f * -1
  end
end
