module Admin::OrderHelper

  def payment_types(order, allowed_payment_types = nil)
    allowed_payment_types.nil? ? payment_types_for(order) : allowed_payment_types
  end

end
