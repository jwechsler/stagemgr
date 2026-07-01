class ServiceLineItem < LineItem
  belongs_to :order, inverse_of: :service_line_items

  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  validates :facility_fee, numericality: true
  validates :description, :facility_fee, :amount, presence: true
  attr_accessor :name

  def total
    if order.nil? || order.payment_type.nil?
      amount
    elsif suppress_for_pass_payments? && order.payment_type.is_a?(PassPaymentType)
      0.0
    else
      amount
    end
  end
end
