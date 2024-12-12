class PriceOverridePayment < Payment
  attr_accessor :override_type

  belongs_to :source_payment_type, :class_name=>'PaymentType'

  def payment_type
    if self.override_type.nil?
      if self.source_payment_type.nil?
        self.override_type = PriceOverridePaymentType.find_or_create_by(allow_for_box_office: false)
      else
        self.override_type = PriceOverridePaymentType.find_or_create_by(report_as_sales_collected:self.source_payment_type.report_as_sales_collected?,
                                   report_as_production_revenue:self.source_payment_type.report_as_sales_collected?, allow_for_box_office: false)
      end
    else
      self.override_type
    end
  end

  def can_cancel?
    true
  end

  def receipt_description
    'Payment'
  end
  
end
