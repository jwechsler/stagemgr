class Payment < ActiveRecord::Base
  audited

  belongs_to :order
  belongs_to :payment_type

  validates_numericality_of :amount, :unless => :number_of_tickets
  validates_numericality_of :number_of_tickets, :unless => :amount
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

  def create_exchange_offset_payment
    # ExchangePayment.new(:amount => -1*self.order.payments(true).to_a.sum { |p| p.amount }, :note => self.order.description)

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

