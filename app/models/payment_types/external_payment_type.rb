class ExternalPaymentType < PaymentType
  def build_payment(amount, order, _payment_details = {})
    if restrict_to_ticket_classes.present? && order.respond_to?(:ticket_line_items)
      allowed_class_codes = restrict_to_ticket_classes.split(',')
      order.ticket_line_items.map do |tli|
        raise "This payment type is restricted to #{restrict_to_ticket_classes.upcase} tickets" unless !allowed_class_codes.select do |code|
          tli.ticket_class.class_code.upcase.start_with?(code)
        end.empty?
      end
    end
    ExternalPayment.new(amount: amount, order: order, payment_type: self)
  end

  def create_refund_payment(_cc_number = nil, _note = nil)
    refund_payment = ReversalPayment.create(amount: amount * -1, order: order, payment_id: id)
    order.payments << refund_payment
    refund_payment
  end

  def ==(other)
    instance_of?(other.class) && display_name == other.display_name
  end

  def payment_classes
    super + [ExternalPayment.class]
  end
end
