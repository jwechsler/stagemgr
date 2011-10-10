class PercentOffSpecialOffer < SpecialOffer
  def calculate_discount(order)
    self.applicable_line_items(order).map{|li|li.total}.sum * self.amount/-100
  end
  
  def to_s
    "#{amount}% off / #{super}"
  end
end
