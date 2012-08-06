class Payment < ActiveRecord::Base
  acts_as_audited

  belongs_to :order
  validates_numericality_of :amount, :unless => :number_of_tickets
  validates_numericality_of :number_of_tickets, :unless => :amount
  default_scope :order=>'created_at asc'
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
    "#{Money.from_numeric(amount)} #{self.class}"
  end
  def payment_type=(string)
    self.type=string
  end
  def process!
    self.processed_on = Date.today
    self.save!
  end
  def self.descendants
    result = []
    ObjectSpace.each_object(Class).each { |c| result << c if c < Payment }
    result
  end

  def release_tickets!

  end

  def refund!(cc_number = nil, note = nil)
    Payment.transaction do
      refund_payment = self.dup
      refund_payment.amount = refund_payment.amount*-1
      refund_payment.order = order
      self.order.payments << refund_payment
      refund_payment.save!
    end
  end

  protected
  def set_processed_on
    self.processed_on = Date.today if (self.new_record? || self.amount_changed?)
  end

end
