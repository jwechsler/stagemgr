class PriceOverridePayment < Payment
  attr_accessor :override_type

  belongs_to :source_payment_type, class_name: 'PaymentType'

  def payment_type
    if override_type.nil?
      report_as_sales = source_payment_type&.report_as_sales_collected? || false
      self.override_type = PriceOverridePaymentType.find_or_create_by(
        report_as_sales_collected: report_as_sales,
        report_as_production_revenue: report_as_sales,
        allow_for_box_office: false
      )
    else
      override_type
    end
  end

  def can_cancel?
    true
  end

  def receipt_description
    'Payment'
  end
end
