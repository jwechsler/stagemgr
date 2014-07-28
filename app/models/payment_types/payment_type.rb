class PaymentType < ActiveRecord::Base

  has_many :payments
  has_many :payment_restrictions, :dependent=>:destroy
  has_many :order_task_suppressions, :dependent=>:destroy
  accepts_nested_attributes_for :order_task_suppressions, :reject_if => proc { |attributes| attributes['task_type'].blank? }, :allow_destroy=>true

  before_destroy :prevent_orphans

  validates_uniqueness_of :display_name

  def self.valid_payment_types_for(current_user)
    if (!current_user.nil? && (current_user.is_administrator? || current_user.is_box_office_user?))
      valid_payment_types = PaymentType.find_all_by_allow_for_box_office(true)
    else
      valid_payment_types = PaymentType.find_all_by_allow_for_public(true)
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


  def to_label
   self.display_name
  end

  def payment_classes
    []
  end

  def allowed_payment_types_for_exchange(current_user)
    PaymentType.all
    []
  end

  def prevent_orphans
    if self.payments.count > 0
      self.errors[:base] << "#{self.display_name} has payments associated with it.  Cannot be deleted"
      false
    else
      true
    end
  end


end
