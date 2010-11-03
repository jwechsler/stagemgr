class AmountOffSpecialOffer < SpecialOffer
  def calculate_discount(order)
    # the discount will either be negative the amount configured
    # or negative the sum total of all tickets of this class
    # which ever one is smaller
    self.amount * self.applicable_line_items(order).to_a.sum{|li| li.respond_to?(:ticket_count) ? li.ticket_count : 0} * -1
  end
  def to_s
    "#{amount} off"
  end
  
end
