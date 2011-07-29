class CashPayment < Payment
  def refund!(cc_number = nil, note = nil)
    CashPayment.transaction do
      refund_payment = self.clone
      refund_payment.amount = refund_payment.amount*-1
      refund_payment.order = order
      self.order.cash_payments << refund_payment
      refund_payment.save!
    end
  end
end
