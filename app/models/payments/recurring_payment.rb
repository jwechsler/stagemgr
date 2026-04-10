class RecurringPayment < Payment

  def receipt_description
    'Payment'
  end
  
  def calculate_processing_fee
    (0.22 + self.amount * 0.022).round(2)
  end

end