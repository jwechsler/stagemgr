class TicketClassAllocation < ActiveRecord::Base
  belongs_to :performance
  belongs_to :ticket_class
  validates_presence_of :performance
  validates_presence_of :ticket_class
  validates_numericality_of :limit, :allow_nil => true
end
