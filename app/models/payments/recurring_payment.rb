class RecurringPayment < Payment

  def receipt_description
    'Payment'
  end
  
  def processing_fee
    0.22 + self.amount * 0.022
  end

end