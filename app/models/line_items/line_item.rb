class LineItem < ActiveRecord::Base
  belongs_to :ticket_class
  belongs_to :order

  validates_presence_of :ticket_class, :ticket_count, :order

  def production_code=(string)
    @prodution_code=string
  end
  def production_code()
    self.performance.try(:production).try(:production_code) || @production_code
  end
  def performance_code=(string)
    self.performance = Performance.find_by_performance_code(string)
  end
  def performance_code()
    self.performance.try(:performance_code)
  end
  def ticket_class_code=(string)
    self.ticket_class=TicketClass.find_by_class_code(string)
  end
  def ticket_class_code
    self.ticket_class.try(:class_code)
  end
  def performance_and_ticket_class_codes=(string)
    performance_code_string, ticket_class_code_string = string.split('-')
    self.performance_code=performance_code_string
    self.ticket_class_code=ticket_class_code_string
  end
  def performance_and_ticket_class_codes
    "#{performance_code}-#{ticket_class_code}"
  end

end

