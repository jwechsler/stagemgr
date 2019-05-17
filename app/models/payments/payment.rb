class Payment < ActiveRecord::Base

  belongs_to :order
  belongs_to :payment_type

  validates_numericality_of :amount, :unless => :number_of_tickets
  validates_numericality_of :number_of_tickets, :unless => :amount
  validates_presence_of :order
  default_scope { order(created_at: :asc )}
  before_save :set_processed_on

  def customer_visible_amount
    self.amount
  end

  def receipt_description
    ''
  end

  def processing_fee
    return 0
  end

  def to_s
    "#{amount.to_money} #{self.class}"
  end

  def payment_info
    ""
  end

  # creates an exchange payment to offset the current payment
  def new_exchange_offset_payment
    ExchangePayment.new(
      amount: -1*self.amount,
      order: self.order,
      note: "Exchange for order #{self.order.id}",
      payment_type: self.payment_type,
      payment_id: self.id
    )
  end

  def process!(order = nil)
    self.processed_on = Time.now
    self.save!
    self
  end

  def self.descendants
    result = []
    ObjectSpace.each_object(Class).each { |c| result << c if c < Payment }
    result
  end

  def release_tickets!

  end

  def can_cancel?
    false
  end

  def create_refund_payment(cc_number = nil, note = nil)
    refund_payment = self.dup
    refund_payment.amount = refund_payment.amount*-1
    refund_payment.order = order
    self.order.payments << refund_payment
    refund_payment
  end

  def refund!(cc_number = nil, note = nil)
    Payment.transaction do
      refund_payment = create_refund_payment(cc_number, note)
      refund_payment.save!
    end
  end

  def report_as_sales_income?
    self.payment_type_id.nil? ? true : self.payment_type.report_as_sales_income?
  end

  def display_name
    if payment_type.nil?
      self.type[0..-8]
    else
      payment_type.display_name
    end
  end

  protected
  def set_processed_on
    self.processed_on = self.processed_on || Time.now if self.new_record?
  end

end

class Class
  def subclasses
    ObjectSpace.each_object(Class).select { |klass| klass < self }
  end
end

