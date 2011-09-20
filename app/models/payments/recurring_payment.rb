class RecurringPayment < Payment

  def processing_fee
    0.22 + self.amount * 0.022
  end

end