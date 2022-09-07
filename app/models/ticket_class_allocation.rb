class TicketClassAllocation < ApplicationRecord
  belongs_to :performance
  belongs_to :ticket_class
  default_scope { includes(:ticket_class) }
  validates_presence_of :performance
  validates_presence_of :ticket_class
  validates_numericality_of :ticket_limit, :allow_nil => true
  validates_numericality_of :shift_days_before_performance, :allow_nil=>true
  validates_numericality_of :shift_when_capacity_over, :allow_nil=>true
  validates_presence_of :shift_to_code, :if=>:shiftable?
  validates_presence_of :shift_days_before_performance, :if=>Proc.new { |tca| tca.shiftable? && tca.shift_when_capacity_over.nil? }
  validates_presence_of :shift_when_capacity_over, :if=>Proc.new { |tca| tca.shiftable? && tca.shift_days_before_performance.nil? }


  def trigger_satisfied?(seats_currently_held = nil)
    self.shiftable? && (self.trigger_satisfied_by_capacity?(seats_currently_held) || self.trigger_satisifed_by_current_date?) && !self.shift_to_code.eql?(self.ticket_class.class_code)
  end

  def trigger_satisifed_by_current_date?
    return false if self.shift_days_before_performance.nil?
    Date.today + self.shift_days_before_performance.days >= self.performance.performance_date
  end

  def trigger_satisfied_by_capacity?(seats_currently_held)
    return false if self.shift_when_capacity_over.nil?

    seats_currently_held = self.performance.seats_held if seats_currently_held.nil?
    seats_currently_held.to_f / self.performance.production.capacity * 100.0 >= self.shift_when_capacity_over
  end


end
