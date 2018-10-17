class PriceOverridePayment < Payment

  def can_cancel?
    true
  end

  def report_as_sales_income?
    false
  end

end
