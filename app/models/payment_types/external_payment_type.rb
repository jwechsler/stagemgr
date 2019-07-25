class ExternalPaymentType < PaymentType

  def build_payment(amount, order, payment_details={})
    unless self.restrict_to_ticket_classes.blank?
      if order.respond_to?(:ticket_line_items) then
        allowed_class_codes = self.restrict_to_ticket_classes.split(',')
        order.ticket_line_items.map {|tli|

          raise "This payment type is restricted to #{self.restrict_to_ticket_classes.upcase} tickets" unless allowed_class_codes.select{|code| tli.ticket_class.class_code.upcase.start_with?(code) }.size > 0 }
      end
    end
    new_payment = ExternalPayment.new(:amount => amount, :order=>order, :payment_type=>self)
  end

  def create_refund_payment(cc_number = nil, note = nil)
    refund_payment = ReversalPayment.create(:amount=>self.amount * -1, :order=>self.order, :payment_id=>self.id)
    self.order.payments << refund_payment
    refund_payment
  end

  def ==(another_payment_type)
    self.instance_of?(another_payment_type.class) && self.display_name == another_payment_type.display_name
  end

 def payment_classes
    super + [ExternalPayment.class]
  end

  def report_as_sales_collected?
    self.report_as_sales_collected
  end

end
