class AmountOffSpecialOffer < SpecialOffer
  def calculate_discount(order)
    # the discount will either be negative the amount configured
    # or negative the sum total of all tickets of this class
    # which ever one is smaller
    (self.amount || 0) * (self.applicable_line_items(order).to_a.sum{|li| li.respond_to?(:ticket_count) ? li.ticket_count : 0} || 0) * -1
  end

  def description(order)
        unless amount.nil?
          "$#{'%01.2f' % amount} off #{super}"
        else
          "ERROR amount off"
        end
  end

  def to_s
    unless amount.nil?
      "$#{'%01.2f' % amount} off #{super}"
    else
      "ERROR amount off"
    end
  end

end
