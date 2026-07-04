class CheckPayment < CurrencyPayment
  def create_refund_payment(_cc_number = nil, _note = nil)
    refund_payment = ReversalPayment.create(amount: amount * -1, order: order, payment_id: id)
    order.payments << refund_payment
    refund_payment
  end

  def receipt_description
    'Check'
  end
end
