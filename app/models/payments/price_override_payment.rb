class PriceOverridePayment < Payment
  attr_accessor :override_type

  belongs_to :source_payment_type, :class_name=>'PaymentType'

  def payment_type
    if self.override_type.nil?
      if self.source_payment_type.nil?
        self.override_type = PriceOverridePaymentType.new
      else
        self.override_type = PriceOverridePaymentType.new(report_as_sales_collected:self.source_payment_type.report_as_sales_collected?,
                                   report_as_production_revenue:self.source_payment_type.report_as_sales_collected?)
      end
    else
      self.override_type
    end
  end

  def can_cancel?
    true
  end

end
