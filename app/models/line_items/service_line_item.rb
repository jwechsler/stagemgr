class ServiceLineItem < LineItem

 validates_numericality_of :amount, :greater_than_or_equal_to=>0
 validates_numericality_of :facility_fee
 validates_presence_of :description, :facility_fee, :amount
 attr_accessor :name

  def total
    if (self.order.nil? || self.order.payment_type.nil?)
      return self.amount
    elsif (self.suppress_for_pass_payments? && self.order.payment_type.is_a?(PassPaymentType))
      return 0.0
    else
      return self.amount
    end
  end
end
