class CurrencyPaymentType < PaymentType
  def allowed_payment_types_for_exchange(current_user)
    super + CurrencyPaymentType.all
  end

  def build_exchange_offset_payments(source_payments)
    source_payments.select { |p| p.is_a? ExchangePayment }.map do |p|
      p.new_exchange_offset_payment
    end
  end
end
