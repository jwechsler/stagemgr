class ExternalPayment < Payment
  def customer_visible_amount
    0.0
  end

  def receipt_description
    self.payment_type.display_name
  end
end
