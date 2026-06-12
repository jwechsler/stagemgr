class TicketClassAllocation < ApplicationRecord
  belongs_to :performance, inverse_of: :ticket_class_allocations
  belongs_to :ticket_class, inverse_of: :ticket_class_allocations
  default_scope { includes(:ticket_class) }
  validates :ticket_limit, numericality: { allow_nil: true }
  validates :shift_days_before_performance, numericality: { allow_nil: true }
  validates :shift_when_capacity_over, numericality: { allow_nil: true }
  validates :shift_to_code, presence: { if: :shiftable? }
  validates :shift_days_before_performance, presence: { if: proc { |tca|
    tca.shiftable? && tca.shift_when_capacity_over.nil?
  } }
  validates :shift_when_capacity_over, presence: { if: proc { |tca|
    tca.shiftable? && tca.shift_days_before_performance.nil?
  } }

  def trigger_satisfied?(seats_currently_held = nil)
    shiftable? && (trigger_satisfied_by_capacity?(seats_currently_held) || trigger_satisifed_by_current_date?) && !shift_to_code.eql?(ticket_class.class_code)
  end

  def trigger_satisifed_by_current_date?
    return false if shift_days_before_performance.nil?

    Date.today + shift_days_before_performance.days >= performance.performance_date
  end

  def trigger_satisfied_by_capacity?(seats_currently_held)
    return false if shift_when_capacity_over.nil?

    seats_currently_held = performance.seats_held if seats_currently_held.nil?
    seats_currently_held.to_f / performance.production.capacity * 100.0 >= shift_when_capacity_over
  end
end
