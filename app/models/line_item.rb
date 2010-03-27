class LineItem < ActiveRecord::Base
  belongs_to :performance
  belongs_to :ticket_class
  belongs_to :order
  
  validates_each :ticket_count do |record, attr, value|
    unless record.ticket_class.nil? || record.performance.nil? || value.nil?
      record.errors.add attr, 'is more than the number left'  if value > record.ticket_class.number_left(record.performance)
    end
  end
  
  validates_presence_of :order, :performance, :ticket_class, :ticket_count
end
