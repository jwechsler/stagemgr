class PaymentType < ApplicationRecord
  has_many :payments
  has_many :payment_restrictions, dependent: :destroy, inverse_of: :payment_type
  has_many :order_task_suppressions, dependent: :destroy
  has_many :performances, through: :payment_restrictions, inverse_of: :restricted_payment_types

  accepts_nested_attributes_for :order_task_suppressions, reject_if: proc { |attributes|
    attributes['task_type'].blank?
  }, allow_destroy: true

  before_destroy :prevent_orphans

  validates :display_name, uniqueness: true

  def self.valid_payment_types_for(current_user)
    if current_user.nil?
      valid_payment_types = PaymentType.where(allow_for_public: true).all
    elsif current_user.is_administrator? || current_user.is_box_office_user?
      valid_payment_types = PaymentType.where(allow_for_box_office: true).all
    elsif current_user.is_theater_user?
      valid_payment_types = PaymentType.where(
        'allow_theater_user_holds = ? OR allow_for_public = ?', true, true
      ).all
    end
    valid_payment_types
  end

  # singleton equality for payment types
  def ==(other)
    instance_of? other.class
  end

  def build_payment(_amount, _order, _payment_details = {})
    raise 'New payment type not yet implemented.'
  end

  def to_label
    display_name
  end

  def payment_classes
    []
  end

  def allowed_payment_types_for_exchange(_current_user)
    PaymentType.all
    []
  end

  def prevent_orphans
    if payments.count > 0
      errors.where(:base) << "#{display_name} has payments associated with it.  Cannot be deleted"
      false
    else
      true
    end
  end

  def build_exchange_offset_payments(source_payments)
    source_payments.grep(ExchangePayment).map do |p|
      p.new_exchange_offset_payment
    end
  end
end
