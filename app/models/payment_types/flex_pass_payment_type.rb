class FlexPassPaymentType < PassPaymentType
  def payment_classes
    super + [FlexPassPayment.class]
  end

  def allowed_payment_types_for_exchange(current_user)
    super + FlexPassPaymentType.all
  end

  def build_payment(_amount, order, _payment_details = {})
    flex_pass = FlexPass.find_by_code(order.flex_pass_code)
    raise 'No FlexPass with that code exists' unless flex_pass

    pass_ticket_class = order.production_ticket_class_from_offer(flex_pass.flex_pass_offer)
    total_amount = order.ticket_line_items.inject(0) do |total_amount, li|
      total_amount + (PassPaymentType.applicable_price(li.ticket_class, pass_ticket_class) * li.ticket_count)
    end
    new_payment = FlexPassPayment.new(
      number_of_tickets: order.number_of_tickets,
      flex_pass: flex_pass,
      amount: total_amount,
      payment_type: self,
      order: order
    )
    new_payment.process!(order)
    new_payment
  end
end
