class FlexPassPaymentType < PassPaymentType

  def payment_classes
    super + [FlexPassPayment.class]
  end

  def allowed_payment_types_for_exchange(current_user)
    FlexPassPaymentType.all
  end

  def apply_exchange_offset_payments(source_payments)
    Array.new
  end

  def create_payment!(amount, order, payment_details={})
    flex_pass = FlexPass.find_by_code(order.flex_pass_code)
    raise 'No FlexPass with that code exists' unless flex_pass

    pass_ticket_class = order.production_ticket_class_from_offer(flex_pass.flex_pass_offer)
    total_amount = order.ticket_line_items.inject(0) { |total_amount, li|
      total_amount += PassPaymentType.applicable_price(li.ticket_class, pass_ticket_class) * li.ticket_count
    }
    new_payment = FlexPassPayment.new(
            :number_of_tickets => order.ticket_quantity,
            :flex_pass => flex_pass,
            :amount => total_amount
        )
    new_payment.process!(order)
  end
end
