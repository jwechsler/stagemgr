class ExternalPayment < Payment

  def customer_visible_amount
    0.0
  end

  def create_refund_payment(cc_number = nil, note = nil)
    refund_payment = ReversalPayment.create(:amount=>self.amount * -1, :order=>self.order, :payment_id=>self.id)
    self.order.payments << refund_payment
    refund_payment
  end

  def receipt_description
    self.payment_type.display_name
  end


end
