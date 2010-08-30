class LineItem < ActiveRecord::Base
  belongs_to :order
  attr_accessor :ticket_class_code

  validates_presence_of :order
  
  before_validation :assign_from_attr_accessors
  
  def assign_from_attr_accessors
    return unless self.order && self.order.performance && self.order.performance.ticket_classes.count > 0
    self.ticket_class = self.order.performance.ticket_classes.find_by_class_code @ticket_class_code if @ticket_class_code
  end

  def ticket_class_code
    # self.ticket_class_code || self.ticket_class.try(:class_code)
    self.ticket_class.try(:class_code)
  end
  
  def ticket?
    return false;
  end

end

