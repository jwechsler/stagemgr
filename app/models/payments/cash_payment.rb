class CashPayment < Payment
  def refund!(cc_number = nil, note = nil)
    CashPayment.transaction do
      refund_payment = self.order.cash_payments.create!(:amount=>self.amount*-1,:payment_id=>self.id)
      self.payment_id=refund_payment.id
      self.save!
    end
  end
end
