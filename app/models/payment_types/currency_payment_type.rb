class CurrencyPaymentType < PaymentType

  def allowed_payment_types_for_exchange(current_user)
    super + CurrencyPaymentType.all
  end

  def apply_exchange_offset_payments(source_payments)
    source_payments.select{|p| p.is_a? ExchangePayment}.map{ |p|
      p.save if p.new_record?
      apply_offset_payment = ExchangePayment.create(:amount => -1 * p.amount, :payment_id => p.id)
      p.update_attribute(:payment_id, apply_offset_payment.id)
      apply_offset_payment
    }
  end

end
