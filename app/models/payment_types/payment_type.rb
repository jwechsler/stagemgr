class PaymentType < ApplicationRecord

  has_many :payments
  has_many :payment_restrictions, :dependent=>:destroy, inverse_of: :payment_type
  has_many :order_task_suppressions, :dependent=>:destroy
  has_many :performances, :through=>:payment_restrictions, inverse_of: :restricted_payment_types
  

  accepts_nested_attributes_for :order_task_suppressions, :reject_if => proc { |attributes| attributes['task_type'].blank? }, :allow_destroy=>true

  before_destroy :prevent_orphans

  validates_uniqueness_of :display_name

  def self.valid_payment_types_for(current_user)
    if (!current_user.nil?)
      if (current_user.is_administrator? || current_user.is_box_office_user?)
        valid_payment_types = PaymentType.where(allow_for_box_office:true).all
      elsif (current_user.is_theater_user?)
        valid_payment_types = PaymentType.where(
          "allow_theater_user_holds = ? OR allow_for_public = ?", true, true).all
      end
    else
      valid_payment_types = PaymentType.where(allow_for_public:true).all
    end
    valid_payment_types
  end

  # singleton equality for payment types
  def ==(another_payment_type)
    self.instance_of? another_payment_type.class
  end

  def build_payment(amount, order, payment_details={})
    raise 'New payment type not yet implemented.'
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
      self.errors.where(:base) << "#{self.display_name} has payments associated with it.  Cannot be deleted"
      false
    else
      true
    end
  end

  def build_exchange_offset_payments(source_payments)
    source_payments.select{|p| p.is_a? ExchangePayment}.map{ |p|
      p.new_exchange_offset_payment
    }
  end


end
