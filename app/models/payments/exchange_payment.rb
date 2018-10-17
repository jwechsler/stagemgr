class ExchangePayment < Payment

  def customer_visible_amount
    return -1*super
  end

  def receipt_description
    unless self.order.nil? || self.order.exchange_source.nil?
      source_payment = "Exchg ##{self.order.exchange_source.id}"
    else
      source_payment = "Exchg"
    end
    source_payment
  end

  def display_name
    "#{super} #{self.amount >= 0 ? '' : 'Offset'}"
  end

  def can_cancel?
    true
  end

end
