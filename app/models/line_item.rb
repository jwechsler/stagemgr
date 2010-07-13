class LineItem < ActiveRecord::Base
  belongs_to :ticket_class
  belongs_to :order
  
  validates_each :ticket_count do |record, attr, value|
    unless record.ticket_class.nil? || record.order.nil? || record.order.performance.nil? || value.nil?
      record.errors.add attr, 'is more than the number left'  if value > record.ticket_class.number_left(record.order.performance)
    end
  end

  validates_each :price_override do |record, attr, value|
    if record.ticket_class && record.ticket_class.ticket_type != 'Donation'
      record.errors.add attr, "cannot be used on ticket class type #{record.ticket_class.ticket_type}" unless value.nil?
    end
  end
  validates_numericality_of :price_override, :allow_nil=>true
  
  validates_presence_of :ticket_class, :ticket_count, :order
  
  def price
    (self.price_override || self.ticket_class.try(:ticket_price)) || 0
  end

  def total
    price * (self.ticket_count || 0)
  end
  
  def refund!
    self.order.line_items.create!(self.attributes.merge(:ticket_count=>self.ticket_count*-1))
  end
  
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

