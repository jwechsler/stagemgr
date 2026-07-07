class Payment < ApplicationRecord
  belongs_to :order, inverse_of: :payments
  belongs_to :payment_type

  # validates_numericality_of :amount, :unless => :number_of_tickets
  # validates_numericality_of :number_of_tickets, :unless => :amount
  # validates_presence_of :order
  default_scope { order(created_at: :asc) }
  before_save :set_processed_on
  before_save :persist_processing_fee

  # Scope to filter payments by payment types that should be reported as sales collected.
  scope :reported_as_sales_collected, lambda {
    joins(:payment_type).where(payment_types: { report_as_sales_collected: true })
  }

  # Scope to filter payments by payment types that should be reported as sales collected.
  scope :reported_as_production_revenue, lambda {
    joins(:payment_type).where(payment_types: { report_as_production_revenue: true })
  }

  # Scope to filter payments by override payment types. Used for testing.
  scope :override_payments_only, lambda {
    where(type: 'PriceOverridePayment')
  }

  # Most payments are visible to customer by default, but membership payments and flex pass payments
  # are not, as those numbers are for internal revenue tracking only
  def customer_visible_amount
    amount
  end

  def receipt_description
    Rails.logger.info("WARNING: Payment #{id} does not have a defined receipt description")
    'Payment'
  end

  def calculate_processing_fee
    BigDecimal('0')
  end

  def to_s
    "#{amount.to_money} #{self.class}"
  end

  def payment_info
    ''
  end

  # creates an exchange payment to offset the current payment
  def new_exchange_offset_payment
    ExchangePayment.new(
      amount: -1 * amount,
      order: order,
      note: "Exchange for order #{order.id}",
      payment_type: payment_type,
      payment_id: id
    )
  end

  def new_offset_payment(partial_amount = nil, _number_of_tickets = nil)
    partial_amount = amount if partial_amount.nil?
    new_payment = dup
    new_payment.amount = 0 - partial_amount
    new_payment
  end

  def process!(_order = nil)
    self.processed_on = Time.now
    save!
    self
  end

  # Overrides Rails' tracker so descendants are found even when subclasses
  # haven't been autoloaded yet. Must compare against `self`, not Payment:
  # Rails builds STI type conditions from `descendants`, and comparing against
  # the base class made every subclass scope match every loaded payment type.
  def self.descendants
    result = []
    ObjectSpace.each_object(Class).each { |c| result << c if c < self }
    result
  end

  # null method for payments that don't release associated tickets
  def release_tickets!; end

  # Only allows $0 payments to be cancelled by default

  def can_cancel?
    amount == 0
  end

  def create_refund_payment(_cc_number = nil, _note = nil)
    refund_payment = dup
    refund_payment.amount = 0.0 - refund_payment.amount
    refund_payment.order = order
    order.payments << refund_payment
    refund_payment
  end

  def refund!(cc_number = nil, note = nil)
    return unless create_refund_payment?

    Payment.transaction do
      refund_payment = create_refund_payment(cc_number, note)
      refund_payment.save!
    end
  end

  def report_as_sales_collected?
    payment_type_id.nil? || payment_type.report_as_sales_collected?
  end

  def report_as_production_revenue?
    payment_type_id.nil? || payment_type.report_as_production_revenue?
  end

  def display_name
    if payment_type.nil?
      type[0..-8]
    else
      payment_type.display_name
    end
  end

  protected

  def set_processed_on
    self.processed_on = processed_on || Time.now if new_record?
  end

  def persist_processing_fee
    self.processing_fee = calculate_processing_fee if processing_fee.nil?
  end

  def create_refund_payment?
    amount > 0
  end
end

# class Class
#  def subclasses
#    ObjectSpace.each_object(Class).select { |klass| klass < self }
#  end
# end
