class LineItem < ActiveRecord::Base
  belongs_to :performance
  belongs_to :ticket_class
  belongs_to :order
  
  validates_each :ticket_count do |record, attr, value|
    record.errors.add attr, 'is more than the number left'  if value > record.ticket_class.number_left
  end
  
  validates_presence_of :performance, :ticket_class, :order
end
