class LineItem < ApplicationRecord
  belongs_to :order, optional: true
  attr_accessor :ticket_class_code

  def ticket_class_code
    # self.ticket_class_code || self.ticket_class.try(:class_code)
    ticket_class.try(:class_code)
  end

  def total
    BigDecimal('0')
  end

  def receipt_total
    total
  end

  def receipt_description
    to_s
  end

  def ticket?
    false
  end
end
