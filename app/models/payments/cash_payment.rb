class CashPayment < CurrencyPayment
  def receipt_description
    'Cash'
  end
end
