class TicketClassAllocation < ActiveRecord::Base
  belongs_to :performance
  belongs_to :ticket_class
  validates_presence_of :performance
  validates_presence_of :ticket_class
  validates_numericality_of :ticket_limit, :allow_nil => true
  validates_numericality_of :shift_days_before_performance, :allow_nil=>true
  validates_numericality_of :shift_when_capacity_over, :allow_nil=>true

  def trigger_shift
    self.available = false
    allocation = self.performance.allocation(self.shift_to_code)
    allocation.available = true
    self.save && allocation.save
  end

end
