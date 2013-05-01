class CurrencyPaymentType < PaymentType

  def allowed_payment_types_for_exchange(current_user)
    CurrencyPaymentType.all
  end

  def apply_exchange_offset_payments(source_payments)
    source_payments.select{|p| p.is_a? ExchangePayment}.map{ |p|
      apply_offset_payment = ExchangePayment.new(:amount => -1 * p.amount, :payment_id => p.id))
      p.update_attribute(:payment_id, apply_offset_payment.id)
      apply_offset_payment
    }
  end

  def

  def apply_exchange_payment_forward(original_order, exchange_order)

    exchange_payments_on_original_order = original_order.payments.map {|p| p.create_exchange_offset_payment}
    exchange_payments_toward_exchange_order = exchange_order.payment_type.apply_offset_payments(exchange_payments_on_original_order)

    unless exchange_payment_on_original_order.nil?
      original_order.payments << exchange_payment_on_original_order
      apply_offset_payment = exchange_order.payment_type.apply_offset_payment(exchange_payment_on_original_order)
      unless apply_offset_payment.nil?
        exchange_order.payments << apply_offset_payment
        payment_difference = exchange_order.total - apply_offset_payment.amount
        if payment_difference < 0
          exchange_order.price_override_payments.create!(:amount => payment_difference)
        elsif payment_difference > 0
          exchange_order.create_proper_payment_in_amount_of!(payment_difference)
        end
      end
    end
  end

end
