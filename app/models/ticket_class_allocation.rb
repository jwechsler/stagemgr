class TicketClassAllocation < ActiveRecord::Base
  belongs_to :performance
  belongs_to :ticket_class
  validates_presence_of :performance
  validates_presence_of :ticket_class
end
