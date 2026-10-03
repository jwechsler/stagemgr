class CheckPayment < CurrencyPayment
  # Recorded with the check's payment type: without one the row fails the
  # required payment_type check and the refund raises.
  def create_refund_payment(_cc_number = nil, _note = nil)
    refund_payment = ReversalPayment.new(amount: -refundable_amount, order: order, payment_id: id,
                                         payment_type: payment_type)
    order.payments << refund_payment
    refund_payment
  end

  def receipt_description
    'Check'
  end
end
