class SpecialOffer < ActiveRecord::Base
  validates_presence_of :type, :code
  validates_numericality_of :amount, :null=>false

  attr_accessor :limiting_model_type
  attr_accessor :limiting_id
  #models to limit this special offer to
  belongs_to :theater
  belongs_to :production
  belongs_to :performance
  belongs_to :ticket_class
  
  validate :find_limiting_object
  
  def find_limiting_object
    t, i = limiting_model_type, limiting_id
    self.theater = nil
    self.production = nil
    self.performance = nil
    self.ticket_class = nil
    return if (t.nil? || t.blank?) && (i.nil? || i.blank?)
    limiting_object = case t
    when 'Theater'
      (self.theater = Theater.find_by_id(i)) || 
        errors.add_to_base("Can't find Theater with id: #{i}")
    when 'Production'
      (self.production = Production.find_by_production_code(i)) || 
        errors.add_to_base("Can't find Production with code: #{i}")
    when 'Performance' 
      (self.performance = Performance.find_by_performance_code(i)) ||
        errors.add_to_base("Can't find Performance with code: #{i}")
    when 'TicketClass'
      (self.ticket_class = TicketClass.find_by_class_code(i)) ||
        errors.add_to_base("Can't find Ticket class with code: #{i}")
    when '', nil
      errors.add_to_base("You didn't pick the type but you enterd the id of: #{i}")
    else
      errors.add_to_base('You tried to use an unknown type')
      nil
    end
  end
  
  def limiting_model_type
    @limiting_model_type||=case
    when !self.theater.nil?
      'Theater'
    when !self.production.nil?
      'Production'
    when !self.performance.nil?
      'Performance'
    when !self.ticket_class.nil?
      'TicketClass'
    else
      nil
    end
  end
  
  def limiting_id
    @limiting_id ||= 
      self.theater_id ||
      self.production.nil_or.production_code ||
      self.performance.nil_or.performance_code ||
      self.ticket_class.nil_or.class_code
  end
  
  def applicable_line_items(order)
    return order.ticket_line_items
  end
  
  
  def calculate_discount(order)
    raise 'Inimplemented'
  end
  
end
