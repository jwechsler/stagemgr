class PaymentType < ActiveRecord::Base

  def self.valid_payment_types_for(current_user)
    valid_payment_types = PaymentType.where ("type <> 'PriceOverridePaymentType'")
    unless current_user && (current_user.is_administrator? || current_user.is_box_office_user?)
      valid_payment_types.delete_if {|pt| pt.is_a? CashPaymentType }
    end
    valid_payment_types
  end

  # singleton equality for payment types
  def ==(another_payment_type)
    self.instance_of? another_payment_type.class
  end

  def create_payment!(amount, order, payment_details={})
    raise 'New payment type not yet implemented.'
    case self.payment_type

      when PRICE_OVERRIDE
        new_payment = self.price_override_payments.create!(:amount => amount)
      else

    end
    new_payment
  end

  has_many :payment_restrictions, :dependent=>:destroy


  def to_label
   self.display_name
  end

  def payment_classes
    []
  end

  def allowed_payment_types_for_exchange(current_user)
    self.class.valid_payment_types_for(current_user)
  end


end
