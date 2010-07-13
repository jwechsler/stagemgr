class CashPayment < Payment
  def refund!
    self.order.cash_payments.create!(:amount=>self.amount*-1,:payment_id=>self.id)
  end
end
