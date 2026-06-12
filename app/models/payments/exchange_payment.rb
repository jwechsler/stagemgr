class ExchangePayment < Payment
  belongs_to :flex_pass, optional: true
  belongs_to :membership, optional: true

  def customer_visible_amount
    -1 * super
  end

  def receipt_description
    if order.nil? || order.exchange_source.nil?
      'Exchg'
    else
      "Exchg ##{order.exchange_source.id}"
    end
  end

  def display_name
    "#{super} #{'Offset' unless amount >= 0}"
  end

  def can_cancel?
    true
  end
end
