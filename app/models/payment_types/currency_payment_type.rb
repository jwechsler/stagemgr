class CurrencyPaymentType < PaymentType
  # The exchange order's credits mirroring +source_payments+ (the offsets on
  # +exchanged_order+, not yet attached to it), themselves unattached.
  def build_exchange_offset_payments(source_payments, exchanged_order)
    source_payments.grep(ExchangePayment).map do |p|
      p.new_exchange_offset_payment(exchanged_order)
    end
  end
end
