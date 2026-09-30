class CurrencyPaymentType < PaymentType
  def build_exchange_offset_payments(source_payments)
    source_payments.grep(ExchangePayment).map do |p|
      p.new_exchange_offset_payment
    end
  end
end
