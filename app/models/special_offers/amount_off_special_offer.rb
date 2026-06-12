class AmountOffSpecialOffer < SpecialOffer
  def calculate_discount(order)
    # the discount will either be negative the amount configured
    # or negative the sum total of all tickets of this class
    # which ever one is smaller
    (amount || 0) * (applicable_line_items(order).to_a.sum do |li|
      li.respond_to?(:ticket_count) ? li.ticket_count : 0
    end || 0) * -1
  end

  def calculate_royalty_discount(order)
    (amount || 0) * applicable_line_items(order, false).to_a.sum do |li|
      li.respond_to?(:ticket_count) ? li.ticket_count : 0
    end * -1
  end

  def description(order)
    if amount.nil?
      'ERROR amount off'
    else
      "$#{'%01.2f' % amount} off #{super}"
    end
  end

  def to_s
    if amount.nil?
      'ERROR amount off'
    else
      "$#{'%01.2f' % amount} off #{super}"
    end
  end
end
