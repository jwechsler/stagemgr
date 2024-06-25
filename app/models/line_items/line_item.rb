class LineItem < ApplicationRecord
  belongs_to :order, optional: true
  attr_accessor :ticket_class_code

  def ticket_class_code
    # self.ticket_class_code || self.ticket_class.try(:class_code)
    self.ticket_class.try(:class_code)
  end

  def total
    BigDecimal(0.0,2)
  end

  def receipt_total
    self.total
  end

  def receipt_description
    self.to_s
  end

  def ticket?
    return false;
  end


end

